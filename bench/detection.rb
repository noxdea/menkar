# frozen_string_literal: true

require_relative "../lib/menkar"

source = ("いろはにほへと ちりぬるを\n" * 10_000).encode(Encoding::Windows_31J).b
samples = 21.times.map do
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = Menkar.detect(source)
  raise "incorrect detection" unless result.encoding == Encoding::Windows_31J

  Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
end
elapsed = samples.sort.fetch(samples.length / 2)
raise "64 KiB detection exceeded 20ms: #{(elapsed * 1000).round(2)}ms" if ENV["BUDGET"] == "1" && elapsed > 0.020

puts "64 KiB detection (21-run median): #{(elapsed * 1000).round(2)}ms"
