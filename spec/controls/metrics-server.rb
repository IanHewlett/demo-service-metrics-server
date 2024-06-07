require 'json'

control "metrics-server" do
  title "metrics-server"
  tag "spec"

  app_name = "metrics-server"
  namespace = "kube-system"
  chart_repo = "metrics-server"
  chart_name = "metrics-server"
  # chart_version = env_vars['metrics_server']['chart_version']
  deployment_name = "metrics-server"
  replicas = 1
  node_group = input('management_node_group_name')
  toleration_value = input('management_node_group_role')

  describe 'flux helmrelease' do
    let(:ready_condition) { JSON.parse(`kubectl get helmrelease #{app_name} -n #{namespace} -o jsonpath="{.status.conditions[?(@.type=='Ready')]}"`) }

    it "is in a ready state" do
      expect(ready_condition.dig('status')).to eq("True")
    end
  end

  describe 'deployment' do
    before { `kubectl rollout status deployment #{deployment_name} -n #{namespace} --timeout=1m` }
    let(:resource) { JSON.parse(`kubectl get deployment #{deployment_name} -n #{namespace} -o json`) }

    it "has expected replicas" do
      expect(resource).to have_expected_replicas("#{replicas}".to_i)
      expect(resource).to have_expected_ready_replicas("#{replicas}".to_i)
    end

    # it "has expected chart version" do
    #   expect(resource).to have_expected_chart_version("#{chart_name}", "#{chart_version}")
    # end
  end

  describe 'pods' do
    pods = JSON.parse(`kubectl get pods -n kube-system -l "app.kubernetes.io/name=#{app_name}" -o json`)

    pods.dig('items').each do |pod|
      describe pod.dig('metadata', 'name') do

        it "should run on a #{toleration_value} node" do
          expect(pod).to run_on_node_group("#{node_group}")
        end
      end
    end

    it "should be running on different nodes" do
      expect(pods.dig('items').map { |x| x.dig('spec', 'nodeName') }).to be_unique
    end
  end
end
