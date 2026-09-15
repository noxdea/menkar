# Menkar

Menkar is a pure Ruby library for identifying text bytes before they enter a
UTF-8 editor core. It detects BOMs, binary data, encodings, newline forms, and
indentation, then performs strict and reversible transcoding.

## Installation

```ruby
gem "menkar"
```

## Usage

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

## License

Menkar is available under the MIT License.
