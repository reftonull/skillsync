class Skillsync < Formula
  desc "Sync skills and configuration across development tools"
  homepage "https://github.com/reftonull/skillsync"
  version "0.1.0"

  on_macos do
    url "https://github.com/reftonull/skillsync/releases/download/v#{version}/skillsync-macos-universal.tar.gz"
    # TODO: Update sha256 after first release is published
    sha256 "PLACEHOLDER"
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/reftonull/skillsync/releases/download/v#{version}/skillsync-linux-aarch64.tar.gz"
      sha256 "PLACEHOLDER"
    else
      url "https://github.com/reftonull/skillsync/releases/download/v#{version}/skillsync-linux-x86_64.tar.gz"
      sha256 "PLACEHOLDER"
    end
  end

  license "MIT"

  def install
    bin.install "skillsync"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/skillsync --version", 2)
  end
end
