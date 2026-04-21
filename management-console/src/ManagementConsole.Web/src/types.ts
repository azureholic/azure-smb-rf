export type IacTool = "Terraform" | "Bicep";
export type Scenario = "Baseline" | "Firewall" | "Vpn" | "Full";

export interface AzureSubscription {
  id: string;
  name: string;
  tenantId: string;
  state: string;
}

export interface ScenarioDescriptor {
  id: string;
  name: string;
  summary: string;
  monthlyCostEstimate: string;
  components: string[];
}

export interface DeploymentRequest {
  iac: IacTool;
  scenario: Scenario;
  subscriptionId: string;
  tenantId: string;
  owner: string;
  location: string;
  environment: string;
  hubVnetAddressSpace: string;
  spokeVnetAddressSpace: string;
  onPremisesAddressSpace?: string;
  logAnalyticsDailyCapGb: number;
  budgetAmount: number;
  budgetAlertEmail?: string;
}

export interface DeploymentJobStatus {
  jobId: string;
  state: string;
  exitCode: number;
  startedUtc: string;
  finishedUtc?: string;
  iac: IacTool;
  scenario: Scenario;
}
