#!/usr/bin/env ruby

# require 'pry'
require 'fileutils'
require 'nokogiri'

if ARGV.size < 2
  $stderr.puts "Usage: ruby ./japanese-prepare-optimized-svg-for-react-component.rb STENO_LAYOUT.svg STENOLAYOUTStenoDiagram.js"
  exit 1
end

SOURCE_SVG = ARGV[0]
TARGET_JS = ARGV[1]

JAPANESE_KEYS = [
"the漢", "theLeftKagikakko", "theLeft4", "theLeftた", "theLeftな", "theLeft3", "theLeftか", "theLeftさ", "theLeft2", "theLeftい", "theLeftう", "theLeft1", "theLeftお", "theLeftっ", "theStar", "dash", "theRight4", "theRightた", "theRightな", "theRight3", "theRightか", "theRightさ", "theRight2", "theRightい", "theRightう", "theRight1", "theRightお", "theRightっ", "theRightKagikakko", "theカ"
]

JAPANESE_SYMBOLS = [
  "the漢Symbol", "theLeftKagikakkoSymbol", "theLeft4Symbol", "theLeftたSymbol", "theLeftなSymbol", "theLeft3Symbol", "theLeftかSymbol", "theLeftさSymbol", "theLeft2Symbol", "theLeftいSymbol", "theLeftうSymbol", "theLeft1Symbol", "theLeftおSymbol", "theLeftっSymbol", "theStarSymbol", "dashSymbol", "theRight4Symbol", "theRightたSymbol", "theRightなSymbol", "theRight3Symbol", "theRightかSymbol", "theRightさSymbol", "theRight2Symbol", "theRightいSymbol", "theRightうSymbol", "theRight1Symbol", "theRightおSymbol", "theRightっSymbol", "theRightKagikakkoSymbol", "theカSymbol"
]

japanese_color_config = {}

JAPANESE_KEYS.each do | key |
  japanese_color_config["#{key}OnColor"] = "#7109AA"
  japanese_color_config["#{key}OffColor"] = "#E9D9F2"
end

JAPANESE_SYMBOLS.each do | key |
  japanese_color_config["#{key}OnColor"] = "#FFFFFF"
  japanese_color_config["#{key}OffColor"] = "#FFFFFF"
end

# SVG_WIDTH = 160
SVG_WIDTH = 140
# SVG_WIDTH = 202


source_svg_basename = File.basename(SOURCE_SVG)
OPTIMIZED_SVG = "./optimized-svgs/#{source_svg_basename}"

if !system "node_modules/.bin/svgo --pretty --config=svgo.config.mjs -i #{SOURCE_SVG} -o #{OPTIMIZED_SVG} > /dev/null"
  exit 1
end

@doc = File.open(OPTIMIZED_SVG) { |f| Nokogiri::XML(f) }

svg = @doc.at_css "svg"
svg["width"] = SVG_WIDTH

title = @doc.at_css "title"
# title_content = title.content
title.remove unless title == nil

# if title.content == "japanese-steno" then
g = @doc.at_css "g"
# g_id = g["id"]
# Use this to offset Danish diagram and others by 1 pixel
# g["transform"] = "translate(1 1)"
g["id"] = "xxxstenoboard-xxx + this.props.brief xxx}"
# end

vars = {}

# STENO KEYS
rects = @doc.css "rect"
rects.each do | rect |
  rect_id = rect["id"]

  # steno key strokes
  stroke = rect["stroke"]
  stroke_var_name = rect_id + "StrokeColor"
  stroke_var_value = stroke
  rect["stroke"] = "xxx{" + stroke_var_name + "xxx}"
  vars.store(stroke_var_name, stroke_var_value)

  # steno key fills
  # key_fill = rect["fill"]
  key_fill_var_name_on = rect_id + "OnColor"
  key_fill_var_name_off = rect_id + "OffColor"
  # key_fill_var_value = key_fill
  rect["fill"] = "xxx{this.props." + rect_id + " ? " + key_fill_var_name_on + " : " + key_fill_var_name_off + "xxx}"
  vars.store(key_fill_var_name_on, japanese_color_config[key_fill_var_name_on])
  vars.store(key_fill_var_name_off, japanese_color_config[key_fill_var_name_off])
end



# STENO LETTERS
paths = @doc.css "path"
paths.each do | path |
  path_id = path["id"]

  # steno letter fills
  # letter_fill = path["fill"]
  letter_fill_var_name_on = path_id + "OnColor"
  letter_fill_var_name_off = path_id + "OffColor"
  # letter_fill_var_value = letter_fill
  path["fill"] = "xxx{this.props." + path_id.gsub('Letter','') + " ? " + letter_fill_var_name_on + " : " + letter_fill_var_name_off + "xxx}"
  vars.store(letter_fill_var_name_on, japanese_color_config[letter_fill_var_name_on])
  vars.store(letter_fill_var_name_off, japanese_color_config[letter_fill_var_name_off])
end

File.open(TARGET_JS, 'w') do |target|
  target.puts @doc.to_html
end

jsx = `node_modules/.bin/svg-to-jsx #{TARGET_JS}`

svgjs = ""

jsx.each_line do |raw_line|
  line = raw_line.rstrip
  if line =~ /<svg (.+)>/i
    line = "<svg " + $1 + " aria-hidden={hidden}>"
  end
  line = line.gsub(/"xxx{/,"{")
  line = line.gsub(/xxx}"/,"}")
  line = line.gsub(/"xxxstenoboard-xxx/,'{"stenoboard-"')
  line = line.gsub(/	/,"  ")
  line = "      " + line
  svgjs += line + "\n"
end


File.open(TARGET_JS, 'w') do |target|

  target.puts "import React, { Component } from 'react';"
  target.puts
  target.puts "class " + File.basename(TARGET_JS, ".js") + " extends Component {"
  target.puts "  render() {"
  target.puts
  target.puts "    let hidden = true;"

  vars.each do |key, value|
    target.puts "    let " + key + " = '" + value + "';"
  end

  target.puts

  target.puts "    return ("

  target.puts svgjs

  target.puts "    );"
  target.puts "  }"
  target.puts "}"
  target.puts
  target.puts "export default " + File.basename(TARGET_JS, ".js") + ";"

end

