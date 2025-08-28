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
docker run --rm -it --mount type=bind,source="$(pwd)",target=/project -w /project --network shared_devcontainer_net -p 3333:3000 gcr.io/distroless/static-debian12 /project/target/aarch64-unknown-linux-musl/release/web-api
```

## Command Line Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--dsn <STRING>` | string | `sqlite:data.db` | Database connection string |
| `--migration <PATH>` | path | (none) | Path to migration file |
| `--no-migration` | flag | false | Disable migration execution |
| `--host <STRING>` | string | `0.0.0.0:8080` | Server host and port |
| `--cors <LIST>` | list of string | (empty) | Allowed CORS origins (comma-separated) |
| `--no-cors` | flag | false | Disable CORS |
| `--static-dir <PATH>` | path | (none) | Path to static files directory |
| `--no-static` | flag | false | Disable static file serving |
| `--jwt-issuer <STRING>` | string | crate name | JWT token issuer |
| `--jwt-secret <STRING>` | string | random UUID | JWT signing secret |
| `--jwt-expire <INT>` | integer | `86400` (24h) | JWT expiration time (seconds) |
| `--log-level <STRING>` | string | (none) | Logging level (`info`, `debug`, etc.) |
| `--no-log` | flag | false | Disable logging |

### Example Usage

```bash
# Run server with custom database and port
web-api --dsn sqlite:app.db --host 127.0.0.1:3000

# Run without CORS and static files
web-api --no-cors --no-static

# Run with migration file and debug logging
web-api --migration migration.sql --log-level debug
```