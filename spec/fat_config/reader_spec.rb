module FatConfig
  RSpec.describe Reader do
    describe 'config_paths' do
      let!(:root) { File.expand_path(File.join(__dir__, "/../tmp")) }

      context 'when using XDG without ENV variables' do
        let(:appname) { 'spec' }
        let(:username) { 'test' }
        let(:reader) { Reader.new(appname, root_prefix: root) }

        around do |ex|
          # Set these, otherwise it will use programmer's user name
          old_home = ENV['HOME']
          old_xdg = ENV['XDG_CONFIG_HOME']
          ENV['HOME'] = File.join('/home', username)
          ENV['XDG_CONFIG_HOME'] = "/home/#{username}/.config"
          sys_dir = File.join(root, 'etc', 'xdg', appname)
          FileUtils.mkdir_p(sys_dir)
          sys_file = File.join(sys_dir, 'config.yml')
          usr_dir = File.join(root, 'home', username, '.config', appname)
          FileUtils.mkdir_p(usr_dir)
          usr_file = File.join(usr_dir, 'config.yml')
          FileUtils.touch(sys_file)
          FileUtils.touch(usr_file)
          ex.run
          FileUtils.rm_rf(sys_dir)
          FileUtils.rm_rf(usr_dir)
          ENV['HOME'] = old_home
          ENV['XDG_CONFIG_HOME'] = old_xdg
        end

        it "finds user files" do
          paths = reader.config_paths[:user]
          expect(paths.size).to eq(1)
          good_path = File.join(root, "/home", username, ".config", appname, "config.yml")
          expect(paths.first).to eq(good_path)
        end

        it "finds system files" do
          paths = reader.config_paths[:system]
          expect(paths.size).to eq(1)
          good_path = File.join(root, "/etc/xdg", appname, "config.yml")
          expect(paths.first).to eq(good_path)
        end
      end

      context 'when overriding directories' do
        let(:appname) { 'byr' }
        let(:username) { 'test' }
        let(:usr_dir) { File.join(root, "home", username, "byr", "config") }
        let(:sys_dir) { File.join(root, "etc", "byr") }
        let(:reader) { Reader.new(appname, root_prefix: nil, user_dir: usr_dir, sys_dir: sys_dir) }

        around do |ex|
          begin
            old_home = ENV['HOME']
            # ENV['HOME'] = File.join('/home', username)
            FileUtils.mkdir_p(sys_dir)
            sys_file = File.join(sys_dir, 'config.yml')
            FileUtils.mkdir_p(usr_dir)
            usr_file = File.join(usr_dir, 'config.yml')
            FileUtils.touch(sys_file)
            FileUtils.touch(usr_file)
            ex.run
          rescue => ex
            binding.break
          ensure
            FileUtils.rm_rf(sys_dir)
            FileUtils.rm_rf(usr_dir)
            ENV['HOME'] = old_home
          end
        end

        it "finds user files" do
          paths = reader.config_paths[:user]
          expect(paths.size).to eq(1)
          good_path = File.join(root, "/home", username, "byr/config", "config.yml")
          expect(paths.first).to eq(good_path)
        end

        it "finds system files" do
          paths = reader.config_paths[:system]
          expect(paths.size).to eq(1)
          good_path = File.join(root, "/etc", appname, "config.yml")
          expect(paths.first).to eq(good_path)
        end
      end
    end
  end
end
