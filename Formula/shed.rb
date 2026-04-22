class Shed < Formula
  desc "Ephemeral Python workspaces powered by uv"
  homepage "https://github.com/YOURUSER/shed"
  url "https://github.com/YOURUSER/shed/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "UPDATE_AFTER_RELEASE"
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
