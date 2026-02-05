# Tailwind CSS / DaisyUI 導入手順（Rails 8 + cssbundling-rails + npm）

## 前提
- Rails 8環境
- dev では Node.js 常駐、prod はビルド時のみ Node.js を使用

## 運用ルール
- 保守性を考慮し、動的クラスはなるべく使わない（使う場合は `safelist` に明示）。
- Tailwind の `content` は必ず全Viewを含める。
- dev は `watch:css` を常時起動（`bin/dev` 推奨）。
- prod はビルド時のみ `build:css` を実行し、ランタイムはビルド成果物のみ配信。

---

## 導入手順
1. npm 依存追加
- `tailwindcss`, `@tailwindcss/cli`, `postcss`, `autoprefixer`, `daisyui` を追加。
```bash
# 初回
make npm-root p="tailwindcss @tailwindcss/cli postcss autoprefixer daisyui"
# 初回以降
make npm p="..."
```

2. Tailwind の初期設定
- `tailwind.config.js` を作成。
- `content` に Rails のビュー/ヘルパー/JS を網羅的に指定。
- `plugins` に `require("daisyui")` を追加。
- 必要なら `safelist` を用意（基本は静的列挙で回避）。

3. PostCSS 設定
- Tailwindを素のCSSに変換する設定表
- `postcss.config.js` を作成し、`tailwindcss` と `autoprefixer` を設定。
```js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

4. Tailwind 入力ファイル作成
```bash
touch app/assets/stylesheets/application.tailwind.css
```
- `application.tailwind.css` を作成。
- 先頭に以下を記載:
```css
@import "tailwindcss";
@plugin "daisyui";

/* ここでスキャン対象を明示 */
@source "../views/**/*.erb";
@source "../helpers/**/*.rb";
@source "../javascript/**/*.js";
@source "../assets/stylesheets/**/*.css";
```
- 自作CSSはこの下に追加（CSSはすべてビルド対象に寄せる）

5. npm scripts 追加
- `build:css` → 本番ビルド用に 一度だけ生成
- `watch:css` → 開発中に 自動で再生成

- `build:css` の出力先を `application.css` に設定。

- `package.json` に以下を追加:
```json
  "scripts": {
    "build:css": "tailwindcss -c tailwind.config.js -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/tailwind.css",
    "watch:css": "tailwindcss -c tailwind.config.js -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/tailwind.css --watch"
  }
```

6. Propshaftでビルド成果物を配信
`config\initializers\assets.rb`に下記を追加
```rb
Rails.application.config.assets.paths << Rails.root.join("app/assets/builds")
```

7. レイアウトでビルド成果物を参照
- `application.html.erb`の`stylesheet_link_tag`を修正
```rb
<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
```

8. Home 画面で動作確認
- `index.html.erb` に DaisyUI のコンポーネントを配置。
```rb
<div class="p-8">
  <div class="card bg-base-100 shadow-xl max-w-md">
    <div class="card-body">
      <h2 class="card-title">DaisyUI OK</h2>
      <p>Tailwind + DaisyUI が反映されています。</p>
      <div class="card-actions justify-end">
        <button class="btn btn-primary">確認</button>
      </div>
    </div>
  </div>
</div>
```

- `application.html.erb ` に`body` もしくは `html` に `data-theme="light"` を付与。
```rb
<body data-theme="light">
  <%= yield %>
</body>
```

- cssをビルドし、watchを起動
```
make css-build
make css
```
