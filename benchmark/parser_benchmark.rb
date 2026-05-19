# frozen_string_literal: true

require_relative '../lib/parselly'

parser = Parselly::Parser.new

selectors = {
  simple: 'div#main.content[data-state="ready"]:hover',
  list: (1..100).map { |index| ".item-#{index}[data-index=\"#{index}\"]" }.join(', '),
  deep: "#{'section > ' * 100}article.card:nth-child(2n+1 of .featured)",
  classes: ".#{(1..200).map { |index| "class-#{index}" }.join('.')}"
}.freeze

iterations = Integer(ENV.fetch('ITERATIONS', '1_000'))

def measure(label, iterations)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { yield }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  puts format('%-24s %10.6fs %12.2f/s', label, elapsed, iterations / elapsed)
end

puts "Iterations: #{iterations}"
puts format('%-24s %10s %12s', 'case', 'seconds', 'ops/sec')

selectors.each do |name, selector|
  measure("#{name} tokenize", iterations) do
    Parselly::Lexer.new(selector).tokenize
  end

  measure("#{name} parse", iterations) do
    parser.parse(selector)
  end

  ast = parser.parse(selector)

  measure("#{name} to_selector", iterations) do
    ast.to_selector
  end

  measure("#{name} descendants", iterations) do
    ast.descendants
  end
end
