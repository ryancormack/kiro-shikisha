cask "kiro-kantoku" do
  version "1.0.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/ryancormack/kiro-shikisha/releases/download/v#{version}/KiroKantoku-#{version}.dmg"
  name "Kiro Kantoku"
  desc "macOS GUI for managing Kiro CLI agents and tasks"
  homepage "https://github.com/ryancormack/kiro-shikisha"

  depends_on macos: ">= :sonoma"

  app "KiroKantoku.app"
end
