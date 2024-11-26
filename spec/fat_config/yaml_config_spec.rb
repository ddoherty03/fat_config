# frozen_string_literal: true

require 'spec_helper'

module FatConfig
  RSpec.describe FatConfig do
    context "with YAML Config Files" do
      # Put files here to test file-system dependent specs.
      let(:sandbox_dir) { File.join(__dir__, 'support/sandbox') }

      # Put contents in path relative to SANDBOX
      def setup_test_file(path, content)
        path = File.expand_path(path)
        test_path = File.join(sandbox_dir, path)
        dir_part = File.dirname(test_path)
        FileUtils.mkdir_p(dir_part) unless Dir.exist?(dir_part)
        File.write(test_path, content)
      end

      before do
        # Save these, since they're not specific to this app.
        @xdg_config_dirs = ENV['XDG_CONFIG_DIRS']
        @xdg_config_home = ENV['XDG_CONFIG_HOME']
      end

      after do
        # Restore
        ENV['XDG_CONFIG_DIRS'] = @xdg_config_dirs
        ENV['XDG_CONFIG_HOME'] = @xdg_config_home
        # Remove anything set in examples
        ENV['LABRAT_SYS_CONFIG'] = nil
        ENV['LABRAT_CONFIG'] = nil
        FileUtils.rm_rf(sandbox_dir)
      end

      describe 'Basic YAML reading' do
        let(:reader) { Reader.new('labrat') }
        let(:yaml_str) do
          <<~YAML
            ---
            doe: "a deer, a female deer"
            ray: "a drop of golden sun"
            pi: 3.14159
            xmas: true
            french-hens: 3
            calling-birds:
              - huey
              - dewey
              - louie
              - fred
            xmas-fifth-day: 2024-12-24
            french-hens: 3
            golden-rings: 5
            partridges:
              count: 1
              location: "a pear tree"
            turtle-doves: two
          YAML
        end

        it 'can read a yaml string' do
          hsh = Psych.safe_load(yaml_str, symbolize_names: true, permitted_classes: [Date])
          hsh = hsh.methodize
          expect(hsh.keys).to include(:doe)
          expect(hsh.keys).to include(:french_hens)
          expect(hsh[:calling_birds]).to be_an Array
          expect(hsh[:xmas_fifth_day]).to be_a Date
        end
      end

      describe 'Reading XDG config files' do
        let(:reader) { Reader.new('labrat', root_prefix: sandbox_dir) }

        it 'reads an xdg system config file' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file('/etc/xdg/labrat/config.yml', config_yml)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads an XDG_CONFIG_DIRS xdg system directory config file' do
          # Higher priority XDG
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl_sep: '%%'
          YAML
          setup_test_file('/lib/junk/labrat/config.yml', config_yml)

          # Lower priority XDG
          config2_yml = <<~YAML
            page-width: 3cm
            page-height: 10cm
            delta-x: -4pt
            printer: dymo4
            rows: 10
            columns: 3
          YAML
          setup_test_file('/lib/lowjunk/labrat/config.yml', config2_yml)

          # The first directory in the ENV variable list should take precedence.
          ENV['XDG_CONFIG_DIRS'] = "/lib/junk:#{ENV['XDG_CONFIG_DIRS']}:/lib/lowjunk"
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          # Since these were not specified in the high-priority config, but were in
          # the low-priority config, they get set.
          expect(hsh[:printer]).to eq('dymo4')
          expect(hsh[:rows]).to eq(10)
          expect(hsh[:columns]).to eq(3)
        end

        it 'reads an xdg system ENV-specified config file' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat.yml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], config_yml)
          hsh = reader.read
          # op = ArgParser.new.parse(hsh)
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads an xdg user config file' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.yml", config_yml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads an xdg ENV-specified user config file' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          ENV['LABRAT_CONFIG'] = "/home/#{ENV['USER']}/.labrc"
          setup_test_file(ENV['LABRAT_CONFIG'], config_yml)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'merges an xdg user config into an xdg system config file' do
          sys_config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file('/etc/xdg/labrat/config.yml', sys_config_yml)
          usr_config_yml = <<~YAML
            page-height: 102mm
            delta-x: -3mm
          YAML
          setup_test_file("/home/#{ENV['USER']}/.config/labrat/config.yml", usr_config_yml)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('102mm')
          expect(hsh[:delta_x]).to eq('-3mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads an XDG_CONFIG_HOME xdg user directory config file' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
          YAML
          setup_test_file('~/.foncig/labrat/config.yml', config_yml)

          # The first directory in the ENV variable list should take precedence.
          ENV['XDG_CONFIG_HOME'] = "~/.foncig"
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to be_nil
        end

        it 'reads an empty XDG_CONFIG_HOME xdg user directory config file' do
          setup_test_file('~/.foncig/labrat/config.yml', '')

          # The first directory in the ENV variable list should take precedence.
          ENV['XDG_CONFIG_HOME'] = "~/.foncig"
          hsh = reader.read
          expect(hsh).to be_a Hash
          expect(hsh).to be_empty
        end
      end

      describe 'Reading classic config files' do
        let(:reader) { Reader.new('labrat', xdg: false, root_prefix: sandbox_dir) }

        it 'read an empty classic system config file' do
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.yaml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], '')
          hsh = reader.read
          expect(hsh).to be_a Hash
          expect(hsh).to be_empty
        end

        it 'reads a classic system config file' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.yaml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], config_yml)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic user config file' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file("/home/#{ENV['USER']}/.labrat.yml", config_yml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic user config file in ENV[\'LABRAT_CONFIG\']' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          ENV['LABRAT_CONFIG'] = '~/junk/random/lr.y'
          setup_test_file(ENV['LABRAT_CONFIG'], config_yml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it "reads a classic user rc-style config file in HOME" do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file('~/.labratrc', config_yml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic ~/.labrat config dir in HOME' do
          config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          setup_test_file('~/.labrat/config', config_yml)
          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('101mm')
          expect(hsh[:delta_x]).to eq('-4mm')
          expect(hsh[:delta_y]).to eq('1cm')
          expect(hsh[:nl_sep]).to eq('%%')
          expect(hsh[:printer]).to eq('seiko3')
        end

        it 'reads a classic system and user config files' do
          sys_config_yml = <<~YAML
            page-width: 33mm
            page-height: 101mm
            delta-x: -4mm
            delta-y: 1cm
            nl-sep: '%%'
            printer: seiko3
          YAML
          ENV['LABRAT_SYS_CONFIG'] = '/etc/labrat/config.yaml'
          setup_test_file(ENV['LABRAT_SYS_CONFIG'], sys_config_yml)
          usr_config_yml = <<~YAML
            page-height: 102mm
            delta-x: -7mm
            delta-y: +30mm
            nl-sep: '~~'
          YAML
          setup_test_file('~/.labrat/config.yml', usr_config_yml)

          hsh = reader.read
          expect(hsh[:page_width]).to eq('33mm')
          expect(hsh[:page_height]).to eq('102mm')
          expect(hsh[:delta_x]).to eq('-7mm')
          expect(hsh[:delta_y]).to eq('+30mm')
          expect(hsh[:nl_sep]).to eq('~~')
          expect(hsh[:printer]).to eq('seiko3')
        end
      end
    end
  end
end
