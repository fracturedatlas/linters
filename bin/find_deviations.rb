# frozen_string_literal: true

# Reports config values that deviate from the gem defaults, flagging any
# deviation whose cop lacks an "# Updated ..." marker comment. Exits 1 when
# unmarked deviations exist, so lefthook can gate commits on it.
#
# Usage: bundle exec ruby bin/find_deviations.rb

require 'rubocop'
require 'reek'
require 'yaml'

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

# Maps cop names to the marker comment directly above them, e.g.
# "# Updated Enabled to false".
def marked_cops(path)
  marks = {}
  lines = File.readlines(path)
  lines.each_with_index do |line, i|
    next unless line =~ /^\s*#\s*(Updated|Customized)/i
    next_line = lines[i + 1].to_s
    if (match = next_line.match(%r{\A\s*([\w/]+):\s*$}))
      marks[match[1]] = line.strip
    end
  end
  marks
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

puts
puts unmarked.zero? ? 'All deviations are marked.' : "#{unmarked} unmarked deviation(s)."
exit unmarked.zero? ? 0 : 1