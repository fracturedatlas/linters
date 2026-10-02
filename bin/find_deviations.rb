# frozen_string_literal: true

# Reports config values that deviate from the gem defaults, flagging any
# deviation whose cop lacks an "# Updated ..." marker comment. Exits 1 when
# unmarked deviations exist, so lefthook can gate commits on it.
#
# Herb defaults come from bin/herb-defaults.json, a snapshot of the
# @herb-tools/linter rule defaults matching the version pinned in .herb.yml.
# Regenerate it whenever the pin is bumped (see the JSON's "regenerate" key).
#
# Usage: bundle exec ruby bin/find_deviations.rb

require 'rubocop'
require 'reek'
require 'yaml'
require 'json'

ROOT = File.expand_path('..', __dir__)
METADATA_KEYS = %w[Description StyleGuide References VersionAdded VersionChanged].freeze
# Deviations reviewed and deliberately left unmarked (version drift from the
# 1.75.7-era config, pending-cop toggles, AllCops section). Revisit when the
# config is next regenerated from current defaults.
PUNTED = [
  'AllCops',
  'Gemspec/AddRuntimeDependency',
  'Gemspec/DeprecatedAttributeAssignment',
  'Gemspec/DevelopmentDependencies',
  'Gemspec/RequireMFA',
  'Lint/CopDirectiveSyntax',
  'Style/IfWithBooleanLiteralBranches',
  'Style/ItBlockParameter',
  'Style/RedundantArgument',
  'Style/RedundantCondition',
].freeze

# Maps cop/rule names to the marker comment directly above them, e.g.
# "# Updated Enabled to false". Names may contain hyphens (Herb rules).
def marked_cops(path)
  marks = {}
  lines = File.readlines(path)
  lines.each_with_index do |line, i|
    next unless line =~ /^\s*#\s*(Updated|Customized)/i
    next_line = lines[i + 1].to_s
    if (match = next_line.match(%r{\A\s*([\w/-]+):(?:\s.*)?$}))
      marks[match[1]] = line.strip
    end
  end
  marks
end

# Config comments belong on their own line above the key, never trailing.
# Skips block-scalar bodies (Description: > etc.) and '#' inside URLs/words;
# only a '#' preceded by whitespace and outside double quotes counts.
def report_trailing_comments(path)
  count = 0
  block_indent = nil
  File.readlines(path).each_with_index do |line, i|
    if block_indent
      block_indent = nil if !line.strip.empty? && line !~ /\A {#{block_indent + 1}}/
      next if block_indent
    end
    block_indent = Regexp.last_match(1).length if line =~ /\A(\s*)[\w'"\/-]+:\s*[>|][\w+-]*\s*$/
    next if line =~ /^\s*#/
    next unless (idx = trailing_comment_index(line))
    puts "(trailing comment) #{File.basename(path)}:#{i + 1}: #{line.strip}"
    count += 1
  end
  count
end

def trailing_comment_index(line)
  in_single = in_double = false
  line.chars.each_with_index do |char, i|
    in_single = !in_single if char == "'" && !in_double
    in_double = !in_double if char == '"' && !in_single
    return i if char == '#' && !in_single && !in_double && i.positive? && line[i - 1] =~ /\s/
  end
  nil
end

# The config files store regexes as quoted strings ("/^_$/") where the gem
# defaults use Regexp objects — normalize both sides to regex sources.
# RuboCop's default config also wraps regexes in "(?-mix:...)" strings, uses
# "" where the files use nil, and stores some hashes as YAML strings.
def normalize(value)
  case value
  when Array then value.map { |entry| normalize(entry) }
  when Hash then value.transform_values { |entry| normalize(entry) }
  when Regexp then value.source
  when String
    unwrapped = value.sub(/\A\(\?[a-z-]+:(.*)\)\z/, '\1').sub(%r{\A/(.*)/\z}, '\1')
    if unwrapped.start_with?('{')
      begin
        normalize(YAML.safe_load(unwrapped.gsub('=>', ':')))
      rescue Psych::SyntaxError
        unwrapped
      end
    else
      unwrapped
    end
  when nil then ''
  else value
  end
end

def report(config, defaults, marks, section)
  unmarked = 0
  config.each do |cop, cfg|
    next unless cfg.is_a?(Hash)
    next unless defaults[cop].is_a?(Hash)
    next if PUNTED.include?(cop)
    cfg.each do |key, value|
      dval = defaults[cop][key]
      next if dval.nil? || METADATA_KEYS.include?(key)
      # RuboCop resolves default Include/Exclude patterns against the config
      # dir, baking an absolute prefix into the defaults — strip it.
      dval = dval.map { |entry| entry.to_s.gsub("#{ROOT}/", '') } if dval.is_a?(Array)
      next if normalize(dval).inspect == normalize(value).inspect
      if marks.key?(cop)
        puts "#{section} #{cop}.#{key} = #{value.inspect} (default: #{dval.inspect})  [marked]"
      else
        unmarked += 1
        puts "#{section} #{cop}.#{key} = #{value.inspect} (default: #{dval.inspect})  [UNMARKED]"
      end
    end
  end
  unmarked
end

rubocop_config = YAML.safe_load(File.read(File.join(ROOT, '.rubocop.yml')), permitted_classes: [Regexp, Symbol])
rubocop_defaults = RuboCop::ConfigLoader.default_configuration
rubocop_marks = marked_cops(File.join(ROOT, '.rubocop.yml'))
puts '=== RuboCop deviations (.rubocop.yml) ==='
unmarked = report(rubocop_config, rubocop_defaults, rubocop_marks, '(rubocop)')

reek_config = YAML.safe_load(File.read(File.join(ROOT, '.reek.yml')))
reek_marks = marked_cops(File.join(ROOT, '.reek.yml'))
detectors = Reek::SmellDetectors::BaseDetector.descendants
puts
puts '=== Reek deviations (.reek.yml) ==='
reek_config.fetch('detectors', {}).each do |cop, cfg|
  next unless cfg.is_a?(Hash)
  next if PUNTED.include?(cop)
  klass = detectors.find { |d| d.name.split('::').last == cop }
  unless klass
    puts "(reek) #{cop}: (no detector found)"
    next
  end
  cfg.each do |key, value|
    dval = klass.default_config[key]
    next if dval.nil?
    next if normalize(dval).inspect == normalize(value).inspect
    if reek_marks.key?(cop)
      puts "(reek) #{cop}.#{key} = #{value.inspect} (default: #{dval.inspect})  [marked]"
    else
      unmarked += 1
      puts "(reek) #{cop}.#{key} = #{value.inspect} (default: #{dval.inspect})  [UNMARKED]"
    end
  end
end

herb_path = File.join(ROOT, '.herb.yml')
herb_config = YAML.safe_load(File.read(herb_path))
herb_defaults = JSON.parse(File.read(File.join(ROOT, 'bin', 'herb-defaults.json')))
herb_marks = marked_cops(herb_path)

puts
puts '=== Herb deviations (.herb.yml) ==='

# Top-level keys whose defaults live in the snapshot.
herb_defaults['top_level'].each do |key, dval|
  value = herb_config[key]
  next if value.nil? || value == dval
  if herb_marks.key?(key)
    puts "(herb) #{key} = #{value.inspect} (default: #{dval.inspect})  [marked]"
  else
    unmarked += 1
    puts "(herb) #{key} = #{value.inspect} (default: #{dval.inspect})  [UNMARKED]"
  end
end

herb_config.fetch('linter', {}).fetch('rules', {}).each do |rule, cfg|
  next unless cfg.is_a?(Hash)
  default = herb_defaults['rules'][rule]
  unless default
    puts "(herb) #{rule}: (no such rule in herb-defaults.json — snapshot stale?)"
    next
  end
  cfg.each do |key, value|
    dval = default[key]
    next if dval.nil? || normalize(dval).inspect == normalize(value).inspect
    if herb_marks.key?(rule)
      puts "(herb) #{rule}.#{key} = #{value.inspect} (default: #{dval.inspect})  [marked]"
    else
      unmarked += 1
      puts "(herb) #{rule}.#{key} = #{value.inspect} (default: #{dval.inspect})  [UNMARKED]"
    end
  end
end

puts
puts '=== Trailing comments ==='
trailing = %w[.rubocop.yml .reek.yml .herb.yml].sum do |name|
  path = File.join(ROOT, name)
  next 0 unless File.exist?(path)
  report_trailing_comments(path)
end
puts 'None.' if trailing.zero?

puts
puts unmarked.zero? ? 'All deviations are marked.' : "#{unmarked} unmarked deviation(s)."
exit unmarked.zero? && trailing.zero? ? 0 : 1