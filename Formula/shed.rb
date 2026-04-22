class Shed < Formula
  desc "Ephemeral Python workspaces powered by uv"
  homepage "https://github.com/jedrzej-grabski/shed"
  url "https://github.com/jedrzej-grabski/shed/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"
  license "MIT"

  depends_on "uv"

  def install
    lib.install "shed.sh" => "shed/shed.sh"
    bin.install "bin/shed"
  end

  def caveats
    <<~EOS
      Run `shed` once to auto-configure your shell.
      Or add manually to ~/.zshrc:

        eval "$(shed --init)"
    EOS
  end

  test do
    assert_match "shed", shell_output("bash -c 'source #{lib}/shed/shed.sh && shed --help'")
  end
end
