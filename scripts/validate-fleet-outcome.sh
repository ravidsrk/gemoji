#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <readiness-doc-path>" >&2
  exit 1
}

[[ $# -eq 1 ]] || usage

doc="$1"
[[ -f "$doc" ]] || { echo "error: readiness doc not found: $doc" >&2; exit 1; }

ruby - "$doc" <<'RUBY'
require "yaml"

path = ARGV.fetch(0)
text = File.read(path, encoding: "UTF-8")
unless text.start_with?("---\n")
  warn "error: missing YAML frontmatter"
  exit 1
end

frontmatter = text[/\A---\n(.*?)\n---/m, 1]
unless frontmatter
  warn "error: malformed YAML frontmatter"
  exit 1
end

data = YAML.safe_load(frontmatter, permitted_classes: [], permitted_symbols: [], aliases: false)
unless data.is_a?(Hash) && data.key?("fleet-outcome")
  warn "error: fleet-outcome block missing from frontmatter"
  exit 1
end

outcome = data["fleet-outcome"]
unless outcome.is_a?(Hash)
  warn "error: fleet-outcome must be a mapping"
  exit 1
end

%w[mission status repo base_branch prs_merged].each do |key|
  unless outcome.key?(key)
    warn "error: fleet-outcome.#{key} is required"
    exit 1
  end
end

status = outcome["status"]
unless %w[done partial blocked].include?(status)
  warn "error: invalid fleet-outcome.status: #{status.inspect}"
  exit 1
end

metrics = outcome["metrics"]
if metrics && !metrics.is_a?(Hash)
  warn "error: fleet-outcome.metrics must be a mapping"
  exit 1
end

deferred = outcome["deferred_missions"]
if deferred
  unless deferred.is_a?(Array)
    warn "error: fleet-outcome.deferred_missions must be a list"
    exit 1
  end
  deferred.each do |item|
    unless item.is_a?(Hash) && item.key?("id")
      warn "error: each deferred_missions entry needs an id"
      exit 1
    end
  end
end

puts "ok: fleet-outcome valid (#{outcome['mission']}, status=#{status})"
RUBY