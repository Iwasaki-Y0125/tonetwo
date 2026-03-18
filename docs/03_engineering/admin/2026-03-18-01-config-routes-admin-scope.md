# `config/routes.rb` の `/admin` 公開対象を必要最小限に絞る

## 目的
- `administrate:install` で生成された全管理リソースをそのまま `/admin` に公開しない。
- 初回運用に必要な管理対象だけを残す。

## 公開対象
- `filter_terms`
- `matching_exclusion_terms`

## 非公開対象
- `users`
- `posts`
- `chat_messages`
- `chatrooms`
- `post_terms`
- `sessions`
- `terms`

## 判断メモ
- `filter_terms` と `matching_exclusion_terms` は、管理画面から追加・削除できる運用対象として残す。
- `users` は管理者判定に使っても、一覧公開はせず必要最小限の公開に絞る。
- `posts` と `messages` は独立した admin resource にせず、将来の `post_abuse_reports` / `message_abuse_reports` 起点で扱う。
- routes から外した管理対象の generator 生成物は残さず、必要になった時点で再生成する。
- `/admin` の初回導線は暫定で `filter_terms#index` にする。
- 管理画面の対象が増えてきたら、専用の `admin/home` を追加して入口を分ける。
