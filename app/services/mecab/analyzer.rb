# frozen_string_literal: true

# 動作確認 ==============================
# $ make exec
# $ ruby script/mecab_tokens_cases.rb > tmp/mecab_tokens_cases.log
# ======================================

# MeCabのfeatureの各要素のメモ
# IPA辞書の場合
# surface:   n.surface,  # 表層形(実際の文字列)
# pos:       parts[0],   # 品詞
# pos1:      parts[1],   # 品詞細分類1
# pos2:      parts[2],   # 品詞細分類2
# pos3:      parts[3],   # 品詞細分類3
# conj_type: parts[4],   # 活用型
# conj_form: parts[5],   # 活用形
# base:      parts[6],   # 原形
# read:      parts[7],   # 読み
# pron:      parts[8],   # 発音

require "bundler/setup"
require "natto"

module Mecab
  class Analyzer
    def self.call(text, **kwargs)
      new(**kwargs).tokens(text)
    end

    # 解析用のMeCabオブジェクトを初期化(引数でオプション指定可能)
    # 使いまわしすることでパフォーマンス向上
    def initialize(mecab_args: nil)
      # 1) MeCab辞書ディレクトリ（NEologd）
      # production: Dockerfileで配置した固定パス
      # dev/test: ENV優先。未設定なら mecab-config --dicdir から推測
      base_dic =
        if Rails.env.production?
          ENV.fetch("MECAB_DICDIR", "/usr/local/lib/mecab/dic/mecab-ipadic-neologd")
        else
          ENV["MECAB_DICDIR"].presence ||
            File.join(`mecab-config --dicdir`.strip, "mecab-ipadic-neologd")
        end
      # File.join(a, b) は パスを安全に結合するRuby標準の関数。

      # 2) ユーザー辞書 ( user.dic )
      # production: Dockerfileで配置した固定パス
      # dev/test: Rails.root 配下（開発環境で更新しやすくするため）
      user_dic =
        if Rails.env.production?
          ENV.fetch("MECAB_USER_DIC", "/usr/local/lib/mecab/dic/user.dic")
        else
          Rails.root.join("mecab_userdic/user.dic").to_s
        end

      args = []
      args << "-d #{base_dic}"
      args << "-u #{user_dic}" if File.exist?(user_dic)
      args << mecab_args if mecab_args

      @nm = Natto::MeCab.new(args.join(" "))
    end

    # text -> token配列へ変換
    def tokens(input_text)
      input_text = input_text.to_s
      pre_mecab_text = strip_url(input_text)

      tokens = []

      @nm.parse(pre_mecab_text) do |n|
        next if n.is_eos?
        parts   = n.feature.split(",")
        tokens << {
          surface:   n.surface,  # 表層形(実際の文字列)
          feature:   n.feature,  # 生のfeature（デバッグ用）
          pos:       parts[0],   # 品詞
          pos1:      parts[1],   # 品詞細分類1
          pos2:      parts[2],   # 品詞細分類2
          pos3:      parts[3],   # 品詞細分類3
          conj_type: parts[4],   # 活用型
          conj_form: parts[5],   # 活用形
          base:      parts[6],   # 原形
          read:      parts[7],   # 読み
          pron:      parts[8]   # 発音
        }
      end
      tokens
    end

    private

    def strip_url(input_text)
      input_text.gsub(%r{(?:https?://|www\.)\S+}, "")
    end
  end
end
