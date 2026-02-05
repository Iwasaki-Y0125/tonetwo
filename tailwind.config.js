/** @type {import('tailwindcss').Config} */
module.exports = {
  // Tailwind がクラスを探すファイルの一覧
  content: [
    "./app/views/**/*.erb",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
    "./app/assets/stylesheets/**/*.css",
  ],

  // テーマの拡張領域
  // 色やフォント、スペーシングなどを追加する場所
  // 例: extend: { colors: { brand: "#0EA5E9" } }
  theme: {
    extend: {},
  },

  // DaisyUI を有効にするための指定。
  plugins: [require("daisyui")],

  // safelistとは
  // ビルド時に動的クラスが文字列と判定され画面に反映されない場合に、
  // safelistにいれることでクラスとして強制的に反映させることができる
  // safelist: [
  //   { pattern: /bg-(red|blue|green)-500/ },
  // ]
};
