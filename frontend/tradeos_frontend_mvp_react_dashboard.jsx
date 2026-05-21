export default function TradeOSDashboard() {
  const workflowSteps = [
    'PO Intake',
    'AI Extraction',
    'Invoice Generation',
    'Compliance Validation',
    'Finance Review',
    'Human Approval',
    'Dispatch',
    'Shipment Tracking',
    'Customer Updates'
  ];

  const agents = [
    {
      name: 'Documentation Agent',
      status: 'Active',
      throughput: '92%',
      skills: ['Invoice Generation', 'Packing List', 'COO Validation']
    },
    {
      name: 'Compliance Agent',
      status: 'Active',
      throughput: '88%',
      skills: ['HS Validation', 'DGFT Rules', 'OFAC Screening']
    },
    {
      name: 'Logistics Agent',
      status: 'Active',
      throughput: '81%',
      skills: ['Shipment Tracking', 'Container ETA', 'Freight APIs']
    },
    {
      name: 'Finance Agent',
      status: 'Monitoring',
      throughput: '74%',
      skills: ['LC Validation', 'Invoice Matching', 'ERP Sync']
    },
    {
      name: 'Communication Agent',
      status: 'Active',
      throughput: '96%',
      skills: ['WhatsApp AI', 'Email Parsing', 'Arabic Translation']
    },
    {
      name: 'Supervisor Agent',
      status: 'Active',
      throughput: '99%',
      skills: ['Approvals', 'Escalations', 'Audit Logs']
    }
  ];

  const documents = [
    'Commercial Invoice',
    'Packing List',
    'Certificate of Origin',
    'Bill of Lading',
    'Shipping Bill',
    'Insurance Certificate',
    'LC Document Set'
  ];

  const complianceChecks = [
    'DGFT Validation',
    'ICEGATE Status',
    'UAE Customs Check',
    'OFAC Screening',
    'HS Code Verification',
    'Export License Check',
    'Restricted Goods Scan',
    'FEMA Compliance'
  ];

  const logisticsSteps = [
    'Cargo Ready',
    'Freight Booked',
    'Customs Clearance',
    'Port Handling',
    'Vessel Loaded',
    'In Transit',
    'Delivered'
  ];

  return (
    <div className="min-h-screen bg-black text-white">
      <div className="flex">
        <aside className="w-72 border-r border-zinc-800 min-h-screen p-6 bg-zinc-950">
          <div className="mb-10">
            <h1 className="text-3xl font-bold">TradeOS</h1>
            <p className="text-zinc-400 text-sm mt-1">Agentic AI Export Operating System</p>
          </div>

          <nav className="space-y-3">
            {[
              'Dashboard',
              'Workflow Engine',
              'Agent Hub',
              'AI Communications',
              'Documents',
              'Compliance',
              'Logistics',
              'Finance',
              'Roadmap',
              'Vision'
            ].map((item) => (
              <div
                key={item}
                className="bg-zinc-900 hover:bg-zinc-800 transition-all rounded-xl px-4 py-3 cursor-pointer border border-zinc-800"
              >
                {item}
              </div>
            ))}
          </nav>
        </aside>

        <main className="flex-1 p-8 overflow-auto">
          <div className="flex items-center justify-between mb-8">
            <div>
              <h2 className="text-4xl font-bold">Operational Dashboard</h2>
              <p className="text-zinc-400 mt-2">AI-native export workflow orchestration platform</p>
            </div>

            <div className="flex gap-3">
              <div className="bg-zinc-900 border border-zinc-800 rounded-xl px-4 py-2">EN</div>
              <div className="bg-zinc-900 border border-zinc-800 rounded-xl px-4 py-2">AR</div>
              <div className="bg-zinc-900 border border-zinc-800 rounded-xl px-4 py-2">HI</div>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-10">
            {[
              { title: 'Active Shipments', value: '142' },
              { title: 'Documents Generated', value: '1,284' },
              { title: 'Compliance Success', value: '98.7%' },
              { title: 'AI Throughput', value: '91%' }
            ].map((card) => (
              <div
                key={card.title}
                className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6"
              >
                <p className="text-zinc-400 text-sm">{card.title}</p>
                <h3 className="text-4xl font-bold mt-3">{card.value}</h3>
              </div>
            ))}
          </div>

          <section className="mb-12">
            <h3 className="text-2xl font-semibold mb-6">AI Workflow Engine</h3>

            <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
              {workflowSteps.map((step, index) => (
                <div
                  key={step}
                  className="bg-zinc-900 border border-zinc-800 rounded-2xl p-5"
                >
                  <div className="w-10 h-10 rounded-full bg-white text-black flex items-center justify-center font-bold mb-4">
                    {index + 1}
                  </div>

                  <h4 className="font-semibold">{step}</h4>
                  <p className="text-zinc-400 text-sm mt-2">
                    Autonomous workflow execution node.
                  </p>
                </div>
              ))}
            </div>
          </section>

          <section className="mb-12">
            <h3 className="text-2xl font-semibold mb-6">Agent Hub</h3>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {agents.map((agent) => (
                <div
                  key={agent.name}
                  className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6"
                >
                  <div className="flex items-center justify-between mb-4">
                    <h4 className="text-xl font-semibold">{agent.name}</h4>
                    <span className="text-green-400 text-sm">{agent.status}</span>
                  </div>

                  <div className="mb-4">
                    <div className="flex justify-between text-sm mb-1">
                      <span className="text-zinc-400">Throughput</span>
                      <span>{agent.throughput}</span>
                    </div>

                    <div className="w-full bg-zinc-800 rounded-full h-3">
                      <div
                        className="bg-white h-3 rounded-full"
                        style={{ width: agent.throughput }}
                      />
                    </div>
                  </div>

                  <div className="flex flex-wrap gap-2 mt-4">
                    {agent.skills.map((skill) => (
                      <span
                        key={skill}
                        className="bg-zinc-800 text-zinc-300 text-xs px-3 py-1 rounded-full"
                      >
                        {skill}
                      </span>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </section>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-12">
            <section className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6">
              <h3 className="text-2xl font-semibold mb-5">Generated Documents</h3>

              <div className="space-y-3">
                {documents.map((doc) => (
                  <div
                    key={doc}
                    className="flex items-center justify-between bg-zinc-800 rounded-xl px-4 py-3"
                  >
                    <span>{doc}</span>
                    <span className="text-green-400 text-sm">Ready</span>
                  </div>
                ))}
              </div>
            </section>

            <section className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6">
              <h3 className="text-2xl font-semibold mb-5">Compliance Validation</h3>

              <div className="space-y-3">
                {complianceChecks.map((check) => (
                  <div
                    key={check}
                    className="flex items-center justify-between bg-zinc-800 rounded-xl px-4 py-3"
                  >
                    <span>{check}</span>
                    <span className="text-green-400 text-sm">Passed</span>
                  </div>
                ))}
              </div>
            </section>
          </div>

          <section className="mb-12">
            <h3 className="text-2xl font-semibold mb-6">Shipment Lifecycle</h3>

            <div className="grid grid-cols-1 md:grid-cols-4 lg:grid-cols-7 gap-4">
              {logisticsSteps.map((step, index) => (
                <div
                  key={step}
                  className={`rounded-2xl p-5 border ${
                    index === 4
                      ? 'bg-white text-black border-white'
                      : 'bg-zinc-900 border-zinc-800'
                  }`}
                >
                  <div className="text-sm mb-2">Step {index + 1}</div>
                  <div className="font-semibold">{step}</div>
                </div>
              ))}
            </div>
          </section>

          <section className="bg-zinc-900 border border-zinc-800 rounded-2xl p-8">
            <h3 className="text-3xl font-bold mb-4">TradeOS Vision</h3>

            <p className="text-zinc-300 text-lg leading-relaxed max-w-4xl">
              TradeOS is building AI-native operational infrastructure for export and logistics SMEs.
              The platform combines autonomous agents, workflow orchestration, compliance intelligence,
              and multilingual communication into a unified operating system for global trade.
            </p>

            <div className="grid grid-cols-1 md:grid-cols-5 gap-4 mt-8">
              {[
                'AI Workforce',
                'Workflow Intelligence',
                'Compliance Automation',
                'Cloud Operations',
                'Trade Infrastructure'
              ].map((pillar) => (
                <div
                  key={pillar}
                  className="bg-zinc-800 rounded-xl px-4 py-5 text-center"
                >
                  {pillar}
                </div>
              ))}
            </div>
          </section>
        </main>
      </div>
    </div>
  );
}
