#### 

```
# 共通設定
HOST="http://localhost:3000"
CT="Content-Type: application/json"

# JSON を変数に格納
SIGNUP_JSON='{"account":"user1","password":"pass123","confirmedPassword":"pass123"}'
SIGNIN_JSON='{"account":"user1","password":"pass123"}'
CREATE_TODO_JSON='{"account":"user1","dueDate":"2023-03-01T12:00:00Z","content":"今日やること！","complete":false}'
EDIT_TODO_JSON='{"id":1,"account":"user1","dueDate":"2023-03-01T12:00:00Z","content":"今日やること！","complete":false}'

# 1. サインアップ
curl -i -X POST "$HOST/service/auth/signup" -H "$CT" -d "$SIGNUP_JSON"

# 2. サインインしてトークン取得
TOKEN=$(curl -s -X POST "$HOST/service/auth/signin" -H "$CT" -d "$SIGNIN_JSON" | jq -r '.token')

# 3. コンテンツ登録（POST）
curl -i -X POST "$HOST/service/manage/todo" -H "$CT" -H "Authorization: Bearer $TOKEN" -d "$CREATE_TODO_JSON"

# 4. コンテンツ編集（PUT）未実装
curl -i -X PUT "$HOST/service/manage/todo" -H "$CT" -H "Authorization: Bearer $TOKEN" -d "$EDIT_TODO_JSON"

# 5. コンテンツ削除（DELETE）未実装
curl -i -X DELETE "$HOST/service/manage/todo/1" -H "Authorization: Bearer $TOKEN"

# 6. コンテンツ取得（GET）
curl -s "$HOST/service/todo/1"
curl -s "$HOST/service/todo/1" -H "Authorization: Bearer $TOKEN"
```

```
# postgresqlサーバー起動(postgres-dbボリュームで永続化して、使用するクライアントと同じネットワークを指定するのがキモ)
docker run --rm --name postgres-server -d -v postgres-db:/var/lib/postgresql/data --network shared_devcontainer_net -p 5432:5432 -e POSTGRES_PASSWORD=p@55w0rd postgres:alpine

# サーバーに入る
docker exec -it postgres-server 

# postgresqlクライアントで操作
psql -h localhost -U postgres

# ユーザー確認
\du

# ユーザー追加
create user devusr with password 'devpwd';

\du

# データベースを作成して追加したユーザーをオーナーに
create database dev_db with owner devusr;

\l

quit

psql -h postgres-server -d dev_db -U devusr
```