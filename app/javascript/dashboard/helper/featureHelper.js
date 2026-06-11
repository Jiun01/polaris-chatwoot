const FEATURE_HELP_URLS = {
  agent_bots: '/hc/polaris-help',
  agents: '/hc/polaris-help',
  audit_logs: '/hc/polaris-help',
  campaigns: '/hc/polaris-help',
  canned_responses: '/hc/polaris-help',
  channel_email: '/hc/polaris-help',
  channel_facebook: '/hc/polaris-help',
  custom_attributes: '/hc/polaris-help',
  dashboard_apps: '/hc/polaris-help',
  help_center: '/hc/polaris-help',
  inboxes: '/hc/polaris-help',
  integrations: '/hc/polaris-help',
  labels: '/hc/polaris-help',
  macros: '/hc/polaris-help',
  reports: '/hc/polaris-help',
  sla: '/hc/polaris-help',
  team_management: '/hc/polaris-help',
  webhook: '/hc/polaris-help',
  billing: '/hc/polaris-help',
  saml: '/hc/polaris-help',
  captain_billing: '/hc/polaris-help',
};

export function getHelpUrlForFeature(featureName) {
  return FEATURE_HELP_URLS[featureName];
}
