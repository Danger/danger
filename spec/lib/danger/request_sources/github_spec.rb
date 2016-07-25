# coding: utf-8
require "danger/request_source/request_source"
require "danger/ci_source/circle"
require "danger/ci_source/travis"
require "danger/danger_core/messages/violation"

describe Danger::RequestSources::GitHub do
  describe "the github host" do
    it "sets a default GitHub host" do
      gh_env = { "DANGER_GITHUB_API_TOKEN" => "hi" }
      g = Danger::RequestSources::GitHub.new(stub_ci, gh_env)
      expect(g.host).to eql("github.com")
    end

    it "allows the GitHub host to be overridden" do
      gh_env = { "DANGER_GITHUB_API_TOKEN" => "hi", "DANGER_GITHUB_HOST" => "git.club-mateusa.com" }
      g = Danger::RequestSources::GitHub.new(stub_ci, gh_env)
      expect(g.host).to eql("git.club-mateusa.com")
    end

    it "allows the GitHub API host to be overridden" do
      api_endpoint = "https://git.club-mateusa.com/api/v3/"
      gh_env = { "DANGER_GITHUB_API_TOKEN" => "hi", "DANGER_GITHUB_API_HOST" => api_endpoint }
      g = Danger::RequestSources::GitHub.new(stub_ci, gh_env)
      expect(Octokit.api_endpoint).to eql(api_endpoint)
    end
  end

  describe "valid server response" do
    before do
      gh_env = { "DANGER_GITHUB_API_TOKEN" => "hi" }
      @g = Danger::RequestSources::GitHub.new(stub_ci, gh_env)

      pr_response = JSON.parse(fixture("pr_response"), symbolize_names: true)
      allow(@g.client).to receive(:pull_request).with("artsy/eigen", "800").and_return(pr_response)

      issue_response = JSON.parse(fixture("issue_response"), symbolize_names: true)
      allow(@g.client).to receive(:get).with("https://api.github.com/repos/artsy/eigen/issues/800").and_return(issue_response)
    end

    it "sets its pr_json" do
      @g.fetch_details
      expect(@g.pr_json).to be_truthy
    end

    it "sets its issue_json" do
      @g.fetch_details
      expect(@g.issue_json).to be_truthy
    end

    it "sets the ignored violations" do
      @g.fetch_details
      expect(@g.ignored_violations).to eql(["Developer Specific file shouldn't be changed",
                                            "Some warning"])
    end

    describe "#organisation" do
      it "valid value available" do
        @g.fetch_details
        expect(@g.organisation).to eq("artsy")
      end

      it "no valid value available doesn't crash" do
        @g.issue_json = nil
        expect(@g.organisation).to eq(nil)
      end
    end

    describe "#fetch_repository" do
      before do
        @g.fetch_details
      end

      it "works with valid data" do
        issue_response = JSON.parse(fixture("repo_response"), symbolize_names: true)
        expect(@g.client).to receive(:repo).with("artsy/yolo").and_return(issue_response)

        result = @g.fetch_repository(repository: "yolo")
        expect(result[:url]).to eq("https://api.github.com/repos/Themoji/Danger")
      end

      it "returns nil for no response" do
        expect(@g.client).to receive(:repo).with("artsy/yolo").and_return(nil)

        expect(@g.fetch_repository(repository: "yolo")).to eq(nil)
      end
    end

    describe "#fetch_danger_repo" do
      before do
        @g.fetch_details
      end

      it "tries both 'danger' and 'Danger' as repo, 'Danger' first" do
        issue_response = JSON.parse(fixture("repo_response"), symbolize_names: true)
        expect(@g.client).to receive(:repo).with("artsy/danger").and_return(nil)
        expect(@g.client).to receive(:repo).with("artsy/Danger").and_return(issue_response)

        result = @g.fetch_danger_repo
        expect(result[:url]).to eq("https://api.github.com/repos/Themoji/Danger")
      end

      it "tries both 'danger' and 'Danger' as repo, 'danger' first" do
        issue_response = JSON.parse(fixture("repo_response"), symbolize_names: true)
        expect(@g.client).to receive(:repo).with("artsy/danger").and_return(issue_response)

        result = @g.fetch_danger_repo
        expect(result[:url]).to eq("https://api.github.com/repos/Themoji/Danger")
      end
    end

    describe "#danger_repo?" do
      before do
        @g.fetch_details
        @issue_response = JSON.parse(fixture("repo_response"), symbolize_names: true)
      end

      it "returns true if the repo's name is danger" do
        @issue_response[:name] = "Danger"
        expect(@g.client).to receive(:repo).with("artsy/danger").and_return(@issue_response)
        expect(@g.ci_source).to receive(:repo_slug).and_return("artsy/danger")
        expect(@g.danger_repo?).to eq(true)
      end

      it "returns false if the repo's name is danger (it's eigen)" do
        @issue_response[:name] = "eigen"
        issue_response = JSON.parse(fixture("repo_response"), symbolize_names: true)
        expect(@g.client).to receive(:repo).with("artsy/eigen").and_return(@issue_response)

        expect(@g.danger_repo?).to eq(false)
      end
    end

    describe "#file_url" do
      it "returns a valid URL with the minimum parameters" do
        url = @g.file_url(repository: "danger",
                                path: "path/Dangerfile")
        expect(url).to eq("https://raw.githubusercontent.com//danger/master/path/Dangerfile")
      end

      it "returns a valid URL with more parameters" do
        url = @g.file_url(repository: "danger",
                        organisation: "org_yo",
                              branch: "yolo_branch",
                                path: "path/Dangerfile")
        expect(url).to eq("https://raw.githubusercontent.com/org_yo/danger/yolo_branch/path/Dangerfile")
      end
    end

    # TODO: Move to the plugin
    #
    xdescribe "DSL Attributes" do
      it "sets the right commit sha" do
        @g.fetch_details

        expect(@g.pr_json[:base][:sha]).to eql(@g.base_commit)
        expect(@g.pr_json[:head][:sha]).to eql(@g.head_commit)
        expect(@g.pr_json[:base][:ref]).to eql(@g.branch_for_merge)
      end

      it "sets the right labels" do
        @g.fetch_details
        expect(@g.pr_labels).to eql(["D:2", "Maintenance Work"])
      end
    end

    describe "#generate_comment" do
      before do
        @date = Time.now.strftime("%Y-%m-%d")
        @g.pr_json = { base: { sha: "" }, head: { sha: "" } }

        stub_request(:post, "https://git.club-mateusa.com/api/v3/repos/artsy/eigen/statuses/").
          with(body: "{\"description\":\"All green. Good on 'ya.\",\"context\":\"danger/danger\",\"target_url\":null,\"state\":\"success\"}",
                     headers: { "Accept" => "application/vnd.github.v3+json", "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3", "Authorization" => "token hi", "Content-Type" => "application/json", "User-Agent" => "Octokit Ruby Gem 4.3.0" }).
          to_return(status: 200, body: "", headers: {})
      end

      it "no warnings, no errors, no messages" do
        result = @g.generate_comment(warnings: [], errors: [], messages: [])
        expect(result.gsub(/\s+/, "")).to eq(
          '<palign="right"data-meta="generated_by_danger">Generatedby:no_entry_sign:<ahref="http://danger.systems/">danger</a></p>'
        )
      end

      it "supports markdown code below the summary table" do
        result = @g.generate_comment(warnings: violations(["ups"]), markdowns: markdowns(["### h3"]))
        expect(result.gsub(/\s+/, "")).to eq(
          '<table><thead><tr><thwidth="50"></th><thwidth="100%"data-kind="Warning">1Warning</th></tr></thead><tbody><tr><td>:warning:</td><tddata-sticky="false">ups</td></tr></tbody></table>###h3<palign="right"data-meta="generated_by_danger">Generatedby:no_entry_sign:<ahref="http://danger.systems/">danger</a></p>'
        )
      end

      it "supports markdown only without a table" do
        result = @g.generate_comment(markdowns: markdowns(["### h3"]))
        expect(result.gsub(/\s+/, "")).to eq(
          '###h3<palign="right"data-meta="generated_by_danger">Generatedby:no_entry_sign:<ahref="http://danger.systems/">danger</a></p>'
        )
      end

      it "some warnings, no errors" do
        result = @g.generate_comment(warnings: violations(["my warning", "second warning"]), errors: [], messages: [])
        # rubocop:disable Metrics/LineLength
        expect(result.gsub(/\s+/, "")).to eq(
          '<table><thead><tr><thwidth="50"></th><thwidth="100%"data-kind="Warning">2Warnings</th></tr></thead><tbody><tr><td>:warning:</td><tddata-sticky="false">mywarning</td></tr><tr><td>:warning:</td><tddata-sticky="false">secondwarning</td></tr></tbody></table><palign="right"data-meta="generated_by_danger">Generatedby:no_entry_sign:<ahref="http://danger.systems/">danger</a></p>'
        )
        # rubocop:enable Metrics/LineLength
      end

      it "some warnings with markdown, no errors" do
        warnings = violations(["a markdown [link to danger](https://github.com/danger/danger)", "second **warning**"])
        result = @g.generate_comment(warnings: warnings, errors: [], messages: [])
        # rubocop:disable Metrics/LineLength
        expect(result.gsub(/\s+/, "")).to eq(
          '<table><thead><tr><thwidth="50"></th><thwidth="100%"data-kind="Warning">2Warnings</th></tr></thead><tbody><tr><td>:warning:</td><tddata-sticky="false">amarkdown<ahref="https://github.com/danger/danger">linktodanger</a></td></tr><tr><td>:warning:</td><tddata-sticky="false">second<strong>warning</strong></td></tr></tbody></table><palign="right"data-meta="generated_by_danger">Generatedby:no_entry_sign:<ahref="http://danger.systems/">danger</a></p>'
        )
        # rubocop:enable Metrics/LineLength
      end

      it "a multiline warning with markdown, no errors" do
        warnings = violations(["a markdown [link to danger](https://github.com/danger/danger)\n\n```\nsomething\n```\n\nHello"])
        result = @g.generate_comment(warnings: warnings, errors: [], messages: [])
        # rubocop:disable Metrics/LineLength
        expect(result.gsub(/\s+/, "")).to eq(
          '<table><thead><tr><thwidth="50"></th><thwidth="100%"data-kind="Warning">1Warning</th></tr></thead><tbody><tr><td>:warning:</td><tddata-sticky="false">amarkdown<ahref="https://github.com/danger/danger">linktodanger</a></p><p><code>something</code></p><p>Hello</td></tr></tbody></table><palign="right"data-meta="generated_by_danger">Generatedby:no_entry_sign:<ahref="http://danger.systems/">danger</a></p>'
        )
        # rubocop:enable Metrics/LineLength
      end

      it "some warnings, some errors" do
        result = @g.generate_comment(warnings: violations(["my warning"]), errors: violations(["some error"]), messages: [])
        # rubocop:disable Metrics/LineLength
        expect(result.gsub(/\s+/, "")).to eq(
          '<table><thead><tr><thwidth="50"></th><thwidth="100%"data-kind="Error">1Error</th></tr></thead><tbody><tr><td>:no_entry_sign:</td><tddata-sticky="false">someerror</td></tr></tbody></table><table><thead><tr><thwidth="50"></th><thwidth="100%"data-kind="Warning">1Warning</th></tr></thead><tbody><tr><td>:warning:</td><tddata-sticky="false">mywarning</td></tr></tbody></table><palign="right"data-meta="generated_by_danger">Generatedby:no_entry_sign:<ahref="http://danger.systems/">danger</a></p>'
        )
        # rubocop:enable Metrics/LineLength
      end

      it "deduplicates previous violations" do
        previous_violations = { error: ["an error", "an error"] }
        allow(@g).to receive(:random_compliment).and_return("random compliment")
        result = @g.generate_comment(warnings: [], errors: violations([]), messages: [], previous_violations: previous_violations)
        expect(result).to eq(<<-HTML)
<table>
  <thead>
    <tr>
      <th width="50"></th>
      <th width="100%" data-kind="Error">
          :white_check_mark: random compliment
      </th>
     </tr>
  </thead>
  <tbody>
      <tr>
        <td>:white_check_mark:</td>
        <td data-sticky="true"><del>an error</del></td>
      </tr>
  </tbody>
</table>

<p align="right" data-meta="generated_by_danger">
  Generated by :no_entry_sign: <a href="http://danger.systems/">danger</a>
</p>
        HTML
      end

      it "crosses resolved violations and changes the title" do
        previous_violations = { error: ["an error"] }
        result = @g.generate_comment(warnings: [], errors: [], messages: [], previous_violations: previous_violations)
        expect(result.gsub(/\s+/, "")).to include('<thwidth="100%"data-kind="Error">:white_check_mark:')
        expect(result.gsub(/\s+/, "")).to include('<td>:white_check_mark:</td><tddata-sticky="true"><del>anerror</del></td>')
      end

      it "uncrosses violations that were on the list and happened again" do
        previous_violations = { error: ["an error"] }
        result = @g.generate_comment(warnings: [], errors: violations(["an error"]), messages: [], previous_violations: previous_violations)
        expect(result.gsub(/\s+/, "")).to eq(
          '<table><thead><tr><thwidth="50"></th><thwidth="100%"data-kind="Error">1Error</th></tr></thead><tbody><tr><td>:no_entry_sign:</td><tddata-sticky="false">anerror</td></tr></tbody></table><palign="right"data-meta="generated_by_danger">Generatedby:no_entry_sign:<ahref="http://danger.systems/">danger</a></p>'
        )
      end

      it "counts only unresolved violations on the title" do
        previous_violations = { error: ["an error"] }
        result = @g.generate_comment(warnings: [], errors: violations(["another error"]),
                                     messages: [], previous_violations: previous_violations)
        expect(result.gsub(/\s+/, "")).to include('<thwidth="100%"data-kind="Error">1Error</th>')
      end

      it "needs to include generated_by_danger" do
        result = @g.generate_comment(warnings: violations(["my warning"]), errors: violations(["some error"]), messages: [])
        expect(result.gsub(/\s+/, "")).to include("generated_by_danger")
      end

      it "handles a custom danger_id" do
        result = @g.generate_comment(warnings: violations(["my warning"]), errors: violations(["some error"]),
                                     messages: [], danger_id: "another_danger")
        expect(result.gsub(/\s+/, "")).to include("generated_by_another_danger")
      end

      it "sets data-sticky to true when a violation is sticky" do
        sticky_warning = Danger::Violation.new("my warning", true, nil, nil)
        result = @g.generate_comment(warnings: [sticky_warning], errors: [], messages: [])
        expect(result.gsub(/\s+/, "")).to include('tddata-sticky="true"')
      end

      it "sets data-sticky to false when a violation is not sticky" do
        non_sticky_warning = Danger::Violation.new("my warning", false, nil, nil)
        result = @g.generate_comment(warnings: [non_sticky_warning], errors: [], messages: [])
        expect(result.gsub(/\s+/, "")).to include('tddata-sticky="false"')
      end
    end

    describe "status message" do
      it "Shows a success message when no errors/warnings" do
        message = @g.generate_github_description(warnings: [], errors: [])
        expect(message).to start_with("All green.")
      end

      it "Shows an error messages when there are errors" do
        message = @g.generate_github_description(warnings: violations([1, 2, 3]), errors: [])
        expect(message).to eq("⚠ 3 Warnings. Don't worry, everything is fixable.")
      end

      it "Shows an error message when errors and warnings" do
        message = @g.generate_github_description(warnings: violations([1, 2]), errors: violations([1, 2, 3]))
        expect(message).to eq("⚠ 3 Errors. 2 Warnings. Don't worry, everything is fixable.")
      end

      it "Deals with singualars in messages when errors and warnings" do
        message = @g.generate_github_description(warnings: violations([1]), errors: violations([1]))
        expect(message).to eq("⚠ 1 Error. 1 Warning. Don't worry, everything is fixable.")
      end
    end

    describe "commit status update" do
      before do
        stub_request(:post, "https://git.club-mateusa.com/api/v3/repos/artsy/eigen/statuses/").to_return status: 200
      end

      it "fails when no head commit is set" do
        @g.pr_json = { base: { sha: "" }, head: { sha: "" } }
        expect do
          @g.submit_pull_request_status!
        end.to raise_error("Couldn't find a commit to update its status".red)
      end
    end

    describe "issue creation" do
      before do
        @g.pr_json = { base: { sha: "" }, head: { sha: "" } }
        allow(@g).to receive(:submit_pull_request_status!).and_return(true)
      end

      it "creates an issue if no danger comments exist" do
        issues = []
        allow(@g.client).to receive(:issue_comments).with("artsy/eigen", "800").and_return(issues)

        body = @g.generate_comment(warnings: violations(["hi"]), errors: [], messages: [])
        expect(@g.client).to receive(:add_comment).with("artsy/eigen", "800", body).and_return({})

        @g.update_pull_request!(warnings: violations(["hi"]), errors: [], messages: [])
      end

      it "updates the issue if no danger comments exist" do
        issues = [{ body: "generated_by_danger", id: "12" }]
        allow(@g.client).to receive(:issue_comments).with("artsy/eigen", "800").and_return(issues)

        body = @g.generate_comment(warnings: violations(["hi"]), errors: [], messages: [])
        expect(@g.client).to receive(:update_comment).with("artsy/eigen", "12", body).and_return({})

        @g.update_pull_request!(warnings: violations(["hi"]), errors: [], messages: [])
      end

      it "updates the issue if no danger comments exist and a custom danger_id is provided" do
        issues = [{ body: "generated_by_another_danger", id: "12" }]
        allow(@g.client).to receive(:issue_comments).with("artsy/eigen", "800").and_return(issues)

        body = @g.generate_comment(warnings: violations(["hi"]), errors: [], messages: [], danger_id: "another_danger")
        expect(@g.client).to receive(:update_comment).with("artsy/eigen", "12", body).and_return({})

        @g.update_pull_request!(warnings: violations(["hi"]), errors: [], messages: [], danger_id: "another_danger")
      end

      it "deletes existing issues if danger doesnt need to say anything" do
        issues = [{ body: "generated_by_danger", id: "12" }]
        allow(@g.client).to receive(:issue_comments).with("artsy/eigen", "800").and_return(issues)

        expect(@g.client).to receive(:delete_comment).with("artsy/eigen", "12").and_return({})
        @g.update_pull_request!(warnings: [], errors: [], messages: [])
      end

      it "deletes existing issues if danger doesnt need to say anything and a custom danger_id is provided" do
        issues = [{ body: "generated_by_another_danger", id: "12" }]
        allow(@g.client).to receive(:issue_comments).with("artsy/eigen", "800").and_return(issues)

        expect(@g.client).to receive(:delete_comment).with("artsy/eigen", "12").and_return({})
        @g.update_pull_request!(warnings: [], errors: [], messages: [], danger_id: "another_danger")
      end

      it "updates the issue if danger doesnt need to say anything but there are sticky violations" do
        issues = [{ body: "generated_by_danger", id: "12" }]
        allow(@g).to receive(:parse_comment).and_return({ errors: ["an error"] })
        allow(@g.client).to receive(:issue_comments).with("artsy/eigen", "800").and_return(issues)

        expect(@g.client).to receive(:update_comment).with("artsy/eigen", "12", any_args).and_return({})
        @g.update_pull_request!(warnings: [], errors: [], messages: [])
      end
    end

    describe "comment parsing" do
      it "detects the warning kind" do
        expect(@g.table_kind_from_title("1 Warning")).to eq(:warning)
        expect(@g.table_kind_from_title("2 Warnings")).to eq(:warning)
      end

      it "detects the error kind" do
        expect(@g.table_kind_from_title("1 Error")).to eq(:error)
        expect(@g.table_kind_from_title("2 Errors")).to eq(:error)
      end

      it "detects the warning kind" do
        expect(@g.table_kind_from_title("1 Message")).to eq(:message)
        expect(@g.table_kind_from_title("2 Messages")).to eq(:message)
      end

      it "parses a comment with error" do
        comment = comment_fixture("comment_with_error")
        violations = @g.parse_comment(comment)
        expect(violations).to eq({ error: ["Some error"] })
      end

      it "parses a comment with error and warnings" do
        comment = comment_fixture("comment_with_error_and_warnings")
        violations = @g.parse_comment(comment)
        expect(violations).to eq({ error: ["Some error"], warning: ["First warning", "Second warning"] })
      end

      it "ignores non-sticky violations when parsing a comment" do
        comment = comment_fixture("comment_with_non_sticky")
        violations = @g.parse_comment(comment)
        expect(violations).to eq({ warning: ["First warning"] })
      end

      it "parses a comment with error and warnings removing strike tag" do
        comment = comment_fixture("comment_with_resolved_violation")
        violations = @g.parse_comment(comment)
        expect(violations).to eq({ error: ["Some error"], warning: ["First warning", "Second warning"] })
      end
    end
  end
end
