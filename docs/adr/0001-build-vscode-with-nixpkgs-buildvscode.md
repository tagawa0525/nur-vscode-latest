---
status: accepted
date: 2026-11-14
requires: []
supersedes: []
superseded-by:
issues: ["#11", "#12", "#14"]
---

# ADR-0001: VS Code の derivation を自前で書かず、nixpkgs の buildVscode に version と src を渡して作る

## 背景

このリポジトリは、nixpkgs の `vscode` より新しい版を毎日の自動更新で出す。これまでは `pkgs/vscode/default.nix` と
`pkgs/vscode-insiders/default.nix` に、nixpkgs の `generic.nix` をコピーした約 250 行の derivation をそれぞれ書いていた。

VS Code の配置が変わるたびに（1.122 の ripgrep-universal、1.129 の asar の詰め直し）、自前で追従してきた。その追従で次の
2 つの不具合が入っていた（2026-11-14 に確認）。

- 1.129 の追従（81ba843）で「@vscode/sudo-prompt は上流から消えた」として pkexec のパスの書き換えを外したが、1.146.0 の
  `node_modules.asar` に `@vscode/sudo-prompt/index.js` は残っていて、「Save as Root」が `/usr/bin/pkexec` を探す（#12）
- `sha256` が 1 つで x64 の tarball のハッシュしか持たず、aarch64 と armv7l ではハッシュが合わない（#11）

nixpkgs の `generic.nix`（`buildVscode`）は、これらの配置の変化に `vscodeVersion` で分岐して追従している。nixos-unstable の
`vscode`（1.144.0）に `overrideAttrs` で 1.146.0 の version と src だけを当てると、そのままビルドが通った（2026-11-14）。
nixpkgs 版に無かったのは、同梱の Copilot の `runtime.node` が dlopen する libssl を RUNPATH に足すこと（#10）だけだった。

## 検討した案

1. 自前の derivation を続け、#11 と #12 をその中で直す
2. nixpkgs の `vscode` を `overrideAttrs` して version と src を差し替える
3. nixpkgs の `buildVscode` を直接呼び、version、src、名前（insiders の別名を含む）を渡す

## 決定と理由

案 3 を採る。

- 案 1 は、VS Code の配置の変化を毎回こちらで追う。#12 はその追従の誤りで入り、nixpkgs の側では起きていなかった
- 案 2 は、`generic.nix` の中の配置の分岐（`lib.versionAtLeast vscodeVersion "1.129.0"` など）が、`overrideAttrs` した
  version ではなく nixpkgs の `vscode.nix` の version で決まる。nixpkgs が古い版にいる間に配置が変わると、新しい版の
  tarball に古い版の配置の処理が当たる。また nixpkgs に `vscode-insiders` は無く、insiders の名前（`code-insiders`、
  `Visual Studio Code - Insiders`）は `vscode.nix` の引数 `isInsiders` で付くので、`override` と `overrideAttrs` の
  両方が要る
- 案 3 は、配置の分岐がこちらの version で決まり、名前もこちらで渡せる。`generic.nix` の修正（Electron の依存、
  patchelf、ripgrep の差し替え、desktop item、`fhs` の passthru）をそのまま受けられる

nixpkgs に無い #10 の libssl の RUNPATH は、`buildVscode` の結果に `overrideAttrs` で `postFixup` を足して続ける。

バージョンとアーキテクチャごとのハッシュは、版ごとの `sources.json` に置き、自動更新のワークフローは jq で書き換える
（Nix の式を sed で書き換えるより、キーを取り違えない）。ハッシュはアーキテクチャごとに Microsoft の API から取る。

### 帰結

- 利用する側の nixpkgs に、`buildVscode` と、新しい版の配置に追従した `generic.nix` が要る。nixpkgs が追従する前に
  VS Code の配置が変わると、自動更新のビルドが落ち、nixpkgs が追従するまで版が止まる（壊れた版は出さない）。急ぐときは
  `overrideAttrs` で一時的に補う
- `buildVscode` の引数が nixpkgs で変わると、呼び出しを直す
- 自動更新のワークフローと `nix build .#vscode` は `flake.lock` の nixpkgs を使うので、`generic.nix` の修正は lock を
  更新するまで届かない。lock は `.github/workflows/update-flake-lock.yml` が毎週更新し、`nix flake check` が通ったときだけコミットする（#14）
- Darwin には対応しない（`flake.nix` の `systems` に入れない）。`buildVscode` は Darwin も扱えるので、要るときは
  ハッシュと `systems` を足す
- armv7l-linux は出さない。flake の `systems` に無く、どの check も見ないまま、armhf の API の遅れで x86_64 と aarch64 の
  更新を止めるため（前のハッシュは x64 のもので、もとから壊れていた）
- insiders の src の URL が版に固定されていない問題（#13）は、この決定と別に直す

### 確認

- `nix flake check` の checks で、「Save as Root」の pkexec のパスが書き換わっていること、Copilot の `runtime.node` の
  RUNPATH に openssl があること、アーキテクチャごとに src のハッシュが違うことを確かめる
- `vsce-sign` の libssl は、`generic.nix` が `--add-needed` で足す（`hasVsceSign`）。こちらは `runtime.node` にだけ足し、
  x86_64 と aarch64 で `runtime.node` が見つからなければビルドを止める
- 自動更新のワークフローは、版を上げる前に x86_64 で上の checks をビルドする。aarch64 はビルドせず、ハッシュは Microsoft の
  API の値を使う
