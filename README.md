# tagawa's NUR packages

個人用NURリポジトリ - 常に最新版を使いたいパッケージを提供

## パッケージ

- **vscode**: Visual Studio Code最新版（毎日自動更新）

## 使い方

このリポジトリは自動的にGitHub Actionsで更新されます。
VSCodeの新バージョンがリリースされると、毎日のチェックで自動的に更新されます。

## ローカルでのテスト

```bash
nix-build -A vscode
```

## GitHub Actionsについて

- 毎日UTC 22:30（日本時間7:30）に最新版をチェック
- 新バージョンが見つかった場合、自動的にコミット・プッシュ
- 手動実行も可能（Actions タブから）
