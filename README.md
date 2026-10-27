# terraform-circular-reference

Terraform の state 同士が循環依存しているとどうなるかを試すためのサンプルです。

`state_a` は `state_b` の output `value` を読み、1 を足して自分の `value` にします。`state_b` も同じことを `state_a` に対して行います。交互に apply すると値が増え続け、plan に差分が出なくなる時点は来ません。

```
state_a.value = state_b.value + 1
state_b.value = state_a.value + 1
```

どちらも backend は `local` で、state は各ディレクトリの `terraform.tfstate` に保存されます。使っているのは Terraform に組み込みの `terraform_data` と `terraform_remote_state` だけなので、provider のダウンロードは発生しません。

## 動かし方

初期化します。

```bash
terraform -chdir=state_a init && terraform -chdir=state_b init
```

前回試したときの state が残っていると途中の値から始まります。1 から見たい場合は先に state を消してください。

```bash
rm -f state_a/terraform.tfstate state_a/terraform.tfstate.backup state_b/terraform.tfstate state_b/terraform.tfstate.backup
```

交互に apply します。何回繰り返しても毎回差分が出ます。

```bash
terraform -chdir=state_a apply -auto-approve && terraform -chdir=state_b apply -auto-approve
```

## 実行結果

Terraform v1.17.0 で state を消してから試した結果です。

| 順番 | 実行 | plan の内容 | apply 後の value |
|---|---|---|---|
| 1 | state_a | 1 to add | 1 |
| 2 | state_b | 1 to add | 2 |
| 3 | state_a | `input = 1 -> 3` | 3 |
| 4 | state_b | `input = 2 -> 4` | 4 |
| 5 | state_a | `input = 3 -> 5` | 5 |
| 6 | state_b | `input = 4 -> 6` | 6 |

この後に `terraform -chdir=state_a plan -detailed-exitcode` を実行すると `input = 5 -> 7` が出て、終了コードは差分ありを示す 2 になります。

## 初回 apply の扱い

`terraform_remote_state` は、読み込み先の state ファイルが存在しないと `Unable to find remote state` で失敗します。`defaults` を指定していても、効くのは state はあるが output がまだない場合だけです。循環していると、どちらを先に apply しても相手の state がないので、そのままでは最初の apply ができません。

このサンプルでは `fileexists()` で相手の state ファイルがあるか確認し、ない場合は data source を作らずに 0 から始めるようにしています。

## state を一つにした場合

`single_state` では、同じ「相手の値に 1 を足す」関係を、1 つの state の中にある 2 つのリソースで書いています。

```hcl
resource "terraform_data" "a" {
  input = terraform_data.b.output + 1
}

resource "terraform_data" "b" {
  input = terraform_data.a.output + 1
}
```

state 内の依存関係は Terraform が 1 つのグラフとして組み立てるので、循環は plan の時点でエラーになり、何も作られません。`terraform validate` でも同じエラーが出ます。

```bash
terraform -chdir=single_state init && terraform -chdir=single_state plan
```

```
Error: Cycle:
  terraform_data.a
  terraform_data.b
```

state を分けると、Terraform は別の state への依存を `terraform_remote_state` で読んだ値としてしか扱えません。そのため循環があっても検出されず、apply のたびに差分が出る状態になります。
