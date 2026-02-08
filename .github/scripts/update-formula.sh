#!/bin/bash
set -euo pipefail

VERSION="$1"
SHA_MACOS="$2"
SHA_LINUX_X86="$3"
SHA_LINUX_ARM="$4"

cat <<EOF
class Skillsync < Formula
  desc "Sync skills and configuration across development tools"
  homepage "https://github.com/reftonull/skillsync"
  license "MIT"
  version "${VERSION}"

  on_macos do
    url "https://github.com/reftonull/skillsync/releases/download/v#{version}/skillsync-macos-universal.tar.gz"
    sha256 "${SHA_MACOS}"
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/reftonull/skillsync/releases/download/v#{version}/skillsync-linux-aarch64.tar.gz"
      sha256 "${SHA_LINUX_ARM}"
    else
      url "https://github.com/reftonull/skillsync/releases/download/v#{version}/skillsync-linux-x86_64.tar.gz"
      sha256 "${SHA_LINUX_X86}"
    end
  end

  def install
    bin.install "skillsync"
    generate_completions_from_executable(bin/"skillsync", "--generate-completion-script")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/skillsync --version", 2)
  end
end
EOF
