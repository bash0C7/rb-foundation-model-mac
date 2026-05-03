# frozen_string_literal: true

require "swift_gem/mkmf"

SwiftGem::Mkmf.create_swift_makefile(
  "foundation_model_mac/foundation_model_mac",
  package: "FoundationModelMac",
  source_dir: __dir__
)
