<h1 align="center">Menkar</h1>

<p align="center">
  <strong>Pure Ruby text encoding detection and normalization</strong>
</p>

<p align="center">
  <a href="https://rubygems.org/gems/menkar"><img src="https://img.shields.io/gem/v/menkar.svg?colorB=319e8c" alt="Gem Version"></a>
  <a href="https://rubygems.org/gems/menkar"><img src="https://img.shields.io/gem/dt/menkar.svg" alt="Downloads"></a>
  <img src="https://img.shields.io/badge/ruby-%3E%3D%203.1-ruby.svg" alt="Ruby Version">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#quick-start">Quick Start</a> ·
  <a href="#detection-and-transcoding">Detection</a> ·
  <a href="#corpus-and-accuracy">Accuracy</a>
</p>

---

Menkar is a pure Ruby library for identifying text bytes before they enter a
UTF-8 editor core. It detects BOMs, binary data, encodings, newline forms, and
indentation, then performs strict and reversible transcoding.

## Features

- BOM, binary-data, encoding, newline, and indentation detection
- UTF-8 plus seven Japanese, Chinese, Korean, and Western legacy encodings
- Strict decode, encode, and round-trip checks without replacement characters
- BOM preservation and explicit newline normalization
- Bounded sampling for predictable memory and runtime
- Corpus-backed classification accuracy checks

## Installation

```ruby
gem "menkar"
```

Menkar supports Ruby 3.1 and later.

## Quick Start

```ruby
require "menkar"

bytes = File.binread("legacy.txt")
detection = Menkar.detect(bytes, hint: "Windows-31J")
raise "binary file" if detection.binary

text = Menkar.decode(bytes, detection) # valid UTF-8; original newlines remain
updated = text.sub("旧", "新")

unless Menkar.roundtrip?(updated, detection)
  warn "The edited text cannot be saved in #{detection.encoding.name}"
end
File.binwrite("legacy.txt", Menkar.encode(updated, detection))
```

## Detection and transcoding

`encode` restores the detected BOM and otherwise preserves the string's
newlines byte for byte. Newline conversion is explicit:

```ruby
unix_text, original = Menkar.normalize_newlines(text, to: :lf)
# original is :lf, :crlf, :cr, :mixed, or :none
```

`detect_file` reads at most `sample + 1` bytes; `detect` examines only `sample`
bytes. The default is 64 KiB and the accepted maximum is 16 MiB. Supported
legacy encodings are Windows-31J (Shift_JIS), EUC-JP, ISO-2022-JP,
Windows-1252, GBK, Big5, and EUC-KR. A hint is an encoding name, `Encoding`, or
`{encoding: ...}` and adjusts a statistical score; a BOM always wins.

Detection is evidence, not a save policy. Callers decide whether to reload or
convert, warn for mixed newlines, and require confirmation when `roundtrip?`
is false. Decoding and encoding never replace invalid or undefined characters.

## Corpus and accuracy

The test corpus contains short excerpts from public-domain works: the Iroha,
Ogura Hyakunin Isshu, *I Am a Cat*, *The Pillow Book*, *The Tale of the Heike*,
*The Narrow Road to the Deep North*, and Basho's haiku (Japanese); the
*Analects* and *Tao Te Ching* (Chinese); *Hunminjeongeum* and traditional Korean
proverbs; and Shakespeare's *Hamlet*. `script/build_corpus` reproducibly
transcodes those excerpts into the fixture encodings. The source works are in
the public domain; the generated fixtures are distributed under the
repository's MIT license.

The suite requires at least 98% correct classification for Japanese fixtures
and 90% for the remaining legacy encodings.

## Development

```sh
bundle install
bundle exec rake test
bundle exec rbs -I sig validate
BUDGET=1 bundle exec rake bench
gem build --strict menkar.gemspec
```

## Contributing

Bug reports and pull requests are welcome at https://github.com/noxdea/menkar.

## License

Menkar is available under the [MIT License](LICENSE.txt).
