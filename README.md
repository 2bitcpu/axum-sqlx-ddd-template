# axum-sqlx-ddd-template

Rust で Web API を構築するためのシンプルなテンプレートです。  
**Axum + SQLx + DDD** をベースに、実践的なレイヤードアーキテクチャを採用しています。

- Axum — Web フレームワーク
- SQLx — 非同期 ORM / DB アクセス
- DDD — ドメイン駆動設計の分離されたレイヤー構成

## 特徴

- 認証・TODO のサンプル API 実装
- レイヤーごとのクレート分割（domain / application / infrastructure / presentation）
- 設定ファイル (`web-api.config.yaml`) による柔軟なログ・環境制御
- SQLite 向けマイグレーションスクリプト同梱
- **Unit of Work パターン**によるトランザクション管理  
  → 複数リポジトリを跨ぐ操作を一貫性を保って実行可能

## 使い方

```bash
# ビルド
cargo build

# DB 初期化
sqlite3 app.db < migration.sql

# 起動
cargo run -p web-api
```

## dockerを使用したビルドと実行

このプロジェクトディレクトリでコマンドを実行してください

### ビルド
```
docker run --rm -it --mount type=bind,source="$(pwd)",target=/project -w /project messense/rust-musl-cross:aarch64-musl cargo build --release
```

### 実行
```
docker run --rm -it --mount type=bind,source="$(pwd)",target=/project -w /project -p 3333:3000 gcr.io/distroless/static-debian12 /project/target/aarch64-unknown-linux-musl/release/web-api
```