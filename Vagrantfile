$provision = <<PROVISION
apt-get install -y git

wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
sudo dpkg -i erlang-solutions_1.0_all.deb
sudo apt-get update
sudo apt-get install -y erlang
sudo apt-get install esl-erlang
sudo apt-get install -y elixir
cd /vagrant
mix local.hex --force
mix local.rebar --force
PROVISION

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.hostname = "raxx"
  config.vm.synced_folder ".", "/vagrant"

  config.vm.provision "shell", inline: $provision
end
