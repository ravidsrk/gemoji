# frozen_string_literal: true

module Emoji
  VARIATION_SELECTOR_16 = "\u{fe0f}".freeze
  ZERO_WIDTH_JOINER = "\u{200d}".freeze
  PEOPLE_HOLDING_HANDS = "\u{1f9d1}\u{200d}\u{1f91d}\u{200d}\u{1f9d1}".freeze

  SKIN_TONES = [
    "\u{1F3FB}", # light skin tone
    "\u{1F3FC}", # medium-light skin tone
    "\u{1F3FD}", # medium skin tone
    "\u{1F3FE}", # medium-dark skin tone
    "\u{1F3FF}", # dark skin tone
  ].freeze

  SKIN_TONE_RE = /[\u{1F3FB}-\u{1F3FF}]/

  # Characters which must have VARIATION_SELECTOR_16 to render as color emoji:
  TEXT_GLYPHS = [
    "\u{1f237}", # Japanese “monthly amount” button
    "\u{1f202}", # Japanese “service charge” button
    "\u{1f170}", # A button (blood type)
    "\u{1f171}", # B button (blood type)
    "\u{1f17e}", # O button (blood type)
    "\u{00a9}",  # copyright
    "\u{00ae}",  # registered
    "\u{2122}",  # trade mark
    "\u{3030}",  # wavy dash
  ].freeze
end