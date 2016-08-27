require "pathname"
require "tempfile"

if Gem.win_platform?
  describe Danger::DangerfileJS, host: :github do
    it "raises when you init in Windows" do
      expect { testing_dangerfile_js }.to raise_error SystemExit
    end
  end
else
  describe Danger::DangerfileJS, host: :github do
    it "runs the ruby code for external plugins inside the Dangerfile" do
      dangerfile_code = "git.modified_files()"

      expect_any_instance_of(Danger::DangerfileGitPlugin).to receive(:modified_files).and_return([])

      dm = testing_dangerfile_js
      dm.parse Pathname.new(""), dangerfile_code
    end

    it "runs a core plugin's ruby code inside the js Dangerfile" do
      dangerfile_code = "message('hi')"

      dm = testing_dangerfile_js
      expect { dm.parse(Pathname.new(""), dangerfile_code) }.to_not raise_error
    end

    it "raises elegantly with bad js code inside the Dangerfile" do
      dangerfile_code = "asdas = asdasd + asdasddas"
      dm = testing_dangerfile_js

      expect do
        dm.parse Pathname.new(""), dangerfile_code
      end.to raise_error(Danger::DSLError)
    end

    describe "initializing plugins" do
      it "should add an instance variable to the dangerfile" do
        class DangerTestJavascriptPlugin < Danger::Plugin; end
        dangerfile_code = "test_javascript_plugin"

        dm = testing_dangerfile_js

        expect do
          dm.parse Pathname.new(""), dangerfile_code
        end.to_not raise_error
      end
    end
  end
end
