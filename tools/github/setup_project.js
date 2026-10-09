// Creates (or reuses) a GitHub Projects v2 kanban for the repo, sets the Status
// options to Backlog / Ready / In Progress / Review-Testing / Done / Blocked,
// adds every issue and places it by its state and status:* label.
// Usage: GH=/path/to/gh node tools/github/setup_project.js owner/repo "Project title"
const { execFileSync } = require("child_process");
const GH = process.env.GH || "gh";
const [REPO, TITLE] = process.argv.slice(2);
const OWNER = REPO.split("/")[0];
const gh = args => execFileSync(GH, args, { encoding: "utf8" }).trim();
const gql = (query, vars = {}) => {
  const args = ["api", "graphql", "-f", `query=${query}`];
  for (const [k, v] of Object.entries(vars)) args.push(typeof v === "number" ? "-F" : "-f", `${k}=${v}`);
  return JSON.parse(gh(args));
};

let project = JSON.parse(gh(["project", "list", "--owner", OWNER, "--format", "json"])).projects.find(p => p.title === TITLE);
if (!project) project = JSON.parse(gh(["project", "create", "--owner", OWNER, "--title", TITLE, "--format", "json"]));
console.log("project", project.number, project.url);
try { gh(["project", "link", String(project.number), "--owner", OWNER, "--repo", REPO]); } catch (e) { /* already linked */ }

const fields = JSON.parse(gh(["project", "field-list", String(project.number), "--owner", OWNER, "--format", "json"])).fields;
const status = fields.find(f => f.name === "Status");
const WANT = [
  ["Backlog", "GRAY", "Not yet ready to start"], ["Ready", "BLUE", "Defined, unblocked, can start"],
  ["In Progress", "YELLOW", "Being worked on"], ["Review/Testing", "PURPLE", "Built; verifying"],
  ["Done", "GREEN", "Verified and closed"], ["Blocked", "RED", "Waiting on something external"],
];
const names = (status.options || []).map(o => o.name);
if (JSON.stringify(names) !== JSON.stringify(WANT.map(w => w[0]))) {
  const opts = WANT.map(([name, color, description]) => `{name: ${JSON.stringify(name)}, color: ${color}, description: ${JSON.stringify(description)}}`).join(", ");
  gql(`mutation($id: ID!) { updateProjectV2Field(input: {fieldId: $id, singleSelectOptions: [${opts}]}) { projectV2Field { ... on ProjectV2SingleSelectField { id } } } }`, { id: status.id });
}
const fresh = JSON.parse(gh(["project", "field-list", String(project.number), "--owner", OWNER, "--format", "json"])).fields.find(f => f.name === "Status");
const optId = Object.fromEntries(fresh.options.map(o => [o.name, o.id]));

const issues = JSON.parse(gh(["issue", "list", "-R", REPO, "--state", "all", "--limit", "300", "--json", "number,url,state,labels,title"]));
const items = JSON.parse(gh(["project", "item-list", String(project.number), "--owner", OWNER, "--format", "json", "--limit", "500"])).items;
const have = new Map(items.filter(i => i.content && i.content.url).map(i => [i.content.url, i.id]));
for (const is of issues) {
  let itemId = have.get(is.url);
  if (!itemId) itemId = JSON.parse(gh(["project", "item-add", String(project.number), "--owner", OWNER, "--url", is.url, "--format", "json"])).id;
  const labels = is.labels.map(l => l.name);
  let col = "Backlog";
  if (is.state === "CLOSED") col = "Done";
  else if (labels.includes("status:blocked")) col = "Blocked";
  else if (labels.includes("status:review-testing")) col = "Review/Testing";
  else if (labels.includes("status:in-progress")) col = "In Progress";
  else if (labels.includes("status:ready")) col = "Ready";
  gh(["project", "item-edit", "--id", itemId, "--project-id", project.id, "--field-id", fresh.id, "--single-select-option-id", optId[col]]);
  console.log(`#${is.number} -> ${col}`);
}
console.log("PROJECT_URL", project.url);
