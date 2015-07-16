# see https://github.com/presidentbeef/brakeman/
desc 'Run Brakeman security scanner'
task :brakeman do |t, args|
  old_report = 'reports/old_brakeman.json'
  old_report_exists = File.readable?(old_report)
  cp 'reports/brakeman.json', 'reports/old_brakeman.json' if old_report_exists
  require 'brakeman'

  tracker = Brakeman.run app_path: '.', config_file: 'config/brakeman.yml'
  # https://github.com/presidentbeef/brakeman/blob/3.0_branch/lib/brakeman/report/report_table.rb#L42
  Brakeman.load_brakeman_dependency 'terminal-table'
  tracker.report.require_report 'base'
  custom_report = Class.new(Brakeman::Report::Base) do
    def initialize(tracker)
      super(tracker.instance_variable_get('@app_tree'), tracker)
    end

    def generate
      num_warnings = all_warnings.length

      Terminal::Table.new(headings: ['Scanned/Reported', 'Total']) do |t|
        t.add_row ['Controllers', tracker.controllers.length]
        t.add_row ['Models', tracker.models.length - 1]
        t.add_row ['Templates', number_of_templates(@tracker)]
        t.add_row ['Errors', tracker.errors.length]
        t.add_row ['Security Warnings', "#{num_warnings} (#{warnings_summary[:high_confidence]})"]
        t.add_row ['Ignored Warnings', ignored_warnings.length] unless ignored_warnings.empty?
      end
    end
  end
  report = custom_report.new(tracker)
  STDERR.puts report.generate
  # https://github.com/presidentbeef/brakeman/blob/3.0_branch/lib/brakeman.rb
  if old_report_exists
    require 'multi_json'
    require 'brakeman/differ'
    previous_results = MultiJson.load(File.read(old_report), symbolize_keys: true)[:warnings]
    new_results = MultiJson.load(tracker.report.to_json, symbolize_keys: true)[:warnings]
    STDERR.puts Brakeman::Differ.new(new_results, previous_results).diff
  end
  if report.all_warnings.any?
    STDERR.print "\033[31m" # ansi red
    STDERR.print "Brakeman report 'open reports/brakeman.html'"
    STDERR.print "\033[0m"
    STDERR.puts
    if tracker.options[:exit_on_warn]
      exit Brakeman::Warnings_Found_Exit_Code
    end
  end
end
