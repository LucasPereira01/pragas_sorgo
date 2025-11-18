import React, { useState, useEffect, useRef } from 'react';
import { Line, Pie, Bar, Doughnut } from 'react-chartjs-2';
import { Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend, ArcElement, BarElement } from 'chart.js';
import * as XLSX from 'xlsx';

// Registrar todos os componentes do Chart.js
ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend, ArcElement, BarElement);

// --- SVG Icons ---
const DroneIcon = ({ style, title }) => (
  <img src="/cHJpdmF0ZS9sci9pbWFnZXMvd2Vic2l0ZS8yMDIzLTExL2hpcHBvdW5pY29ybl9yZWFsX3Bob3RvX29mX2Ryb25lX2NhbWVyYV9p.svg" style={{...style, width: '60px', height: '60px'}} title={title} alt="Drone" />
);

const TractorIcon = ({ style, title }) => (
  <img src="/b3617f61-0ba9-4d56-992d-8534ca466d85.svg" style={{...style, width: '70px', height: '70px'}} title={title} alt="Tractor" />
);

const PersonIcon = ({ style, title }) => (
  <img src="/12829748.svg" style={{...style, width: '50px', height: '50px', borderRadius: '50%'}} title={title} alt="Person" />
);


// --- Mapeamento e Cores ---
const getPestColor = (pestType) => {
  if (!pestType) return '#6b7280';
  if (pestType.includes("Pulgão")) return '#ef4444';
  if (pestType.includes("Lagarta")) return '#8b5cf6';
  if (pestType.includes("Mosca")) return '#06b6d4';
  return '#6b7280';
};

// Percursos de patrulha em ZIG-ZAG
const zigZagPath = (x, y, w, h) => [
  { x: `${x}%`, y: `${y}%` }, { x: `${x + w}%`, y: `${y}%` },
  { x: `${x + w}%`, y: `${y + h / 2}%` }, { x: `${x}%`, y: `${y + h / 2}%` },
];

const fieldPaths = {
  1: {
    drone: zigZagPath(11, 10, 26, 28),
    person: zigZagPath(12, 12, 20, 24),
    tractor: zigZagPath(15, 14, 14, 20)
  },
  2: {
    drone: zigZagPath(61, 10, 26, 28),
    person: zigZagPath(62, 12, 20, 24),
    tractor: zigZagPath(65, 14, 14, 20)
  },
  3: {
    drone: zigZagPath(11, 50, 26, 28),
    person: zigZagPath(12, 52, 20, 24),
    tractor: zigZagPath(15, 54, 14, 20)
  },
  4: {
    drone: zigZagPath(61, 50, 26, 28),
    person: zigZagPath(62, 52, 20, 24),
    tractor: zigZagPath(65, 54, 14, 20)
  },
  home: { drone: [{ x: '34%', y: '90%' }] },
  parking: { tractor: [{ x: '75%', y: '90%' }] },
  base: { person: [{ x: '47%', y: '90%' }] }
};

// --- Hooks Customizados ---
const usePatrolMovement = (target, initialPosition) => {
  const { id, type, key } = target;
  const [position, setPosition] = useState(initialPosition);
  const pathIndexRef = useRef(0);

  useEffect(() => {
    const path = fieldPaths[id]?.[type];
    if (!path) return;

    pathIndexRef.current = 0;
    setPosition(path[0]);

    if (path.length > 1) {
      const interval = setInterval(() => {
        pathIndexRef.current = (pathIndexRef.current + 1) % path.length;
        setPosition(path[pathIndexRef.current]);
      }, 4000);
      return () => clearInterval(interval);
    }
  }, [id, type, key]);

  return position;
};

// --- Componentes de UI ---
const FieldVisualization = ({ fields, dronePos, personPos, tractorPos, droneAction, personAction, tractorAction }) => (
    <div className="bg-white p-6 rounded-xl shadow-lg">
      <h2 className="text-2xl font-bold mb-6 text-gray-800">Fazenda de Sorgo - Monitoramento de Pragas</h2>
      <div className="relative w-full h-[550px] bg-gradient-to-b from-sky-200 via-green-100 to-amber-100 rounded-xl overflow-hidden border-2 border-green-200">
        <div className="absolute inset-4 grid grid-cols-2 grid-rows-2 gap-4 h-[75%]">
          {fields.map((field) => {
            const pestTypes = field.pest_type ? field.pest_type.split(',').map(p => p.trim()) : [];
            const primaryPestColor = pestTypes.length > 0 ? getPestColor(pestTypes[0]) : '#22c55e';

            const backgroundStyle = pestTypes.length > 0
              ? `linear-gradient(135deg, ${primaryPestColor} 0%, ${primaryPestColor}99 100%)`
              : 'linear-gradient(135deg, #22c55e 0%, #16a34a 100%)';

            return (
              <div key={field.id} className="relative rounded-lg" style={{ background: backgroundStyle, border: '2px solid #166534', transition: 'background 0.5s ease' }}>
                <div className="absolute top-2 left-2 bg-white bg-opacity-90 px-3 py-1 rounded-full text-sm font-semibold text-gray-800 shadow-md">
                  Talhão {field.id}
                </div>
                {pestTypes.length > 0 && (
                  <div className="absolute bottom-2 right-2 bg-white bg-opacity-90 px-2 py-1 rounded-lg text-xs font-semibold text-gray-800 shadow-md">
                    <div className="font-bold mb-1">Pragas: {field.pests}%</div>
                    {pestTypes.map(pt => <div key={pt}>- {pt}</div>)}
                  </div>
                )}
              </div>
            );
          })}
        </div>
        <div className="absolute bottom-0 left-0 right-0 h-[25%] bg-yellow-100/50 border-t-4 border-yellow-300/80 flex items-end justify-center" style={{backgroundImage: 'url("data:image/svg+xml,%3Csvg width=\'40\' height=\'40\' viewBox=\'0 0 40 40\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cg fill=\'%2392400e\' fill-opacity=\'0.1\'%3E%3Cpath d=\'M0 38.59l2.83-2.83 1.41 1.41L1.41 40H0v-1.41zM10 40h1.41l-1.41-1.41V40zM0 10h1.41L0 11.41V10zM38.59 0l-2.83 2.83 1.41 1.41L40 1.41V0h-1.41zM40 10v1.41L38.59 10H40zM10 0v1.41L11.41 0H10zM0 30h1.41L0 31.41V30zM40 30v1.41L38.59 30H40zM30 0v1.41L31.41 0H30zM30 40h1.41l-1.41-1.41V40z\'/%3E%3C/g%3E%3C/svg%3E")'}}>
            <div className="absolute" style={{left: '18%', bottom: '10%'}}>
                <div className="w-4 h-12 bg-yellow-900/80 rounded-sm"></div>
                <div className="absolute w-16 h-16 bg-green-600 rounded-full" style={{top: '-20px', left: '-25px'}}></div>
                <div className="absolute w-12 h-12 bg-green-600/80 rounded-full" style={{top: '-10px', left: '-45px'}}></div>
                <div className="absolute w-12 h-12 bg-green-600/90 rounded-full" style={{top: '-10px', left: '-5px'}}></div>
            </div>
            <div className="absolute" style={{left: '48%', bottom: '10%'}}>
                <div className="absolute border-l-[48px] border-l-transparent border-r-[48px] border-r-transparent border-b-[30px] border-b-red-700" style={{top: '-30px', left: '0px'}}></div>
                <div className="w-24 h-16 bg-white rounded-sm shadow-lg">
                    <div className="w-full h-3 bg-red-800 rounded-t-sm"></div>
                    <div className="w-6 h-6 bg-blue-200 absolute left-4 top-8 border border-black/50"></div>
                    <div className="w-4 h-10 bg-yellow-700 absolute right-5 top-6 border border-black/50"></div>
                </div>
            </div>
            <div className="absolute" style={{left: '72%', bottom: '10%'}}>
                <div className="w-24 h-12 bg-gray-400 rounded-sm shadow-lg border-b-4 border-gray-600">
                    <div className="w-full h-3 bg-gray-500 rounded-t-sm"></div>
                    <div className="w-20 h-1 bg-black/50 absolute left-2 top-5"></div>
                </div>
            </div>
            <div className="absolute bg-gray-600/50 w-16 h-16 rounded-full flex items-center justify-center text-white font-bold text-3xl" style={{left: '32%', bottom: '10%'}}>H</div>
        </div>
        <DroneIcon style={{ position: 'absolute', top: dronePos.y, left: dronePos.x, transform: 'translate(-50%, -50%)', transition: 'top 3.5s ease-in-out, left 3.5s ease-in-out', zIndex: 30 }} title={droneAction} />
        <TractorIcon style={{ position: 'absolute', top: tractorPos.y, left: tractorPos.x, transform: 'translate(-50%, -50%)', transition: 'top 3.5s ease-in-out, left 3.5s ease-in-out', zIndex: 20 }} title={tractorAction} />
        <PersonIcon style={{ position: 'absolute', top: personPos.y, left: personPos.x, transform: 'translate(-50%, -50%)', transition: 'top 3.5s ease-in-out, left 3.5s ease-in-out', zIndex: 10 }} title={personAction} />
      </div>
    </div>
);

const ChartCard = ({ children }) => (
    <div className="bg-white p-6 rounded-xl shadow-lg">
        <div className="h-96 flex items-center justify-center">
            {children}
        </div>
    </div>
);

const API_URL = 'http://localhost:8000';
const createTarget = (id, type) => ({ id, type, key: Date.now() + Math.random() });

const App = () => {
  const [view, setView] = useState('painel');
  const [pestData, setPestData] = useState([]);
  const [fields, setFields] = useState([
    { id: 1, pests: 0, pest_type: '' }, { id: 2, pests: 0, pest_type: '' },
    { id: 3, pests: 0, pest_type: '' }, { id: 4, pests: 0, pest_type: '' },
  ]);
  const [reports, setReports] = useState([]);
  const [loadingReports, setLoadingReports] = useState(false);
  const [chartData, setChartData] = useState(null);
  
  const [droneTarget, setDroneTarget] = useState(() => createTarget('home', 'drone'));
  const [personTarget, setPersonTarget] = useState(() => createTarget('base', 'person'));
  const [tractorTarget, setTractorTarget] = useState(() => createTarget('parking', 'tractor'));

  const [droneAction, setDroneAction] = useState('Aguardando início do ciclo de coleta');
  const [personAction, setPersonAction] = useState('Aguardando dados para análise');
  const [tractorAction, setTractorAction] = useState('Estacionado na base');
  
  const ws = useRef(null);
  const fullReportRef = useRef({});
  const timelineTimeoutRef = useRef(null);

  const dronePos = usePatrolMovement(droneTarget, fieldPaths.home.drone[0]);
  const personPos = usePatrolMovement(personTarget, fieldPaths.base.person[0]);
  const tractorPos = usePatrolMovement(tractorTarget, fieldPaths.parking.tractor[0]);

  const processReportData = (reports) => {
    if (!reports || reports.length === 0) {
        setChartData(null);
        return;
    }
    const orders = reports.map(r => r.order_data);
    const pestCounts = orders.reduce((acc, order) => {
        acc[order.pest_detected] = (acc[order.pest_detected] || 0) + 1;
        return acc;
    }, {});
    const severityCounts = orders.reduce((acc, order) => {
        acc[order.infestation_severity] = (acc[order.infestation_severity] || 0) + 1;
        return acc;
    }, {});
    const actionMethods = orders.reduce((acc, order) => {
        if (order.worker_task) acc[order.worker_task.method] = (acc[order.worker_task.method] || 0) + 1;
        if (order.tractor_task) acc[order.tractor_task.method] = (acc[order.tractor_task.method] || 0) + 1;
        return acc;
    }, {});
    const infestationByField = orders.reduce((acc, order) => {
        if (!acc[order.field]) acc[order.field] = { total: 0, count: 0 };
        acc[order.field].total += order.infestation_level;
        acc[order.field].count += 1;
        return acc;
    }, {});

    setChartData({
        pestDistribution: {
            labels: Object.keys(pestCounts),
            datasets: [{ data: Object.values(pestCounts), backgroundColor: ['#8b5cf6', '#ef4444', '#06b6d4', '#f59e0b', '#10b981', '#3b82f6'] }]
        },
        severity: {
            labels: ['Leve', 'Moderada', 'Alta'],
            datasets: [{ label: 'Contagem', data: [severityCounts.leve || 0, severityCounts.moderada || 0, severityCounts.alta || 0], backgroundColor: ['#22c55e', '#f59e0b', '#ef4444'] }]
        },
        actionMethods: {
            labels: Object.keys(actionMethods),
            datasets: [{ data: Object.values(actionMethods), backgroundColor: ['#3b82f6', '#10b981', '#f97316', '#8b5cf6'] }]
        },
        infestationByField: {
            labels: Object.keys(infestationByField).map(f => `Talhão ${f}`),
            datasets: [{ label: 'Nível Médio de Infestação', data: Object.values(infestationByField).map(f => f.total / f.count), backgroundColor: '#6366f1' }]
        }
    });
  };

  const fetchReports = async () => {
    setLoadingReports(true);
    try {
      const res = await fetch(`${API_URL}/reports`);
      const data = await res.json();
      setReports(data);
      processReportData(data);
    } catch (err) { console.error(err); setReports([]); }
    setLoadingReports(false);
  };

  const handleExportToExcel = () => {
    if (reports.length === 0) {
        alert("Não há dados para exportar.");
        return;
    }
    const flattenedData = reports.map(report => {
        const order = report.order_data;
        return {
            "Timestamp": new Date(order.timestamp).toLocaleString(),
            "Talhão": order.field,
            "Praga Detectada": order.pest_detected,
            "Nível de Infestação (%)": (order.infestation_level * 100).toFixed(1),
            "Severidade": order.infestation_severity,
            "Ação do Trabalhador": order.worker_task ? order.worker_task.agent : "N/A",
            "Método do Trabalhador": order.worker_task ? order.worker_task.method : "N/A",
            "Ação do Trator": order.tractor_task ? order.tractor_task.agent : "N/A",
            "Método do Trator": order.tractor_task ? order.tractor_task.method : "N/A",
        };
    });
    const worksheet = XLSX.utils.json_to_sheet(flattenedData);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, "RelatorioDeOperacoes");
    XLSX.writeFile(workbook, "Relatorio_Fazenda_Sorgo.xlsx");
  };

  const runTimeline = (timeline) => {
    if (timelineTimeoutRef.current) clearTimeout(timelineTimeoutRef.current);
    const step = timeline.shift();
    if (!step) return;
    step.action();
    if (timeline.length > 0) {
      timelineTimeoutRef.current = setTimeout(() => runTimeline(timeline), step.duration);
    }
  };

  let startActionPhase;

  const startSimulationCycle = () => {
    const TIME_PER_FIELD = 28000;
    const TIME_TO_RETURN = 5000;
    const droneTourPath = [1, 2, 3, 4];
    const droneTimeline = [];

    droneTimeline.push({
        action: () => {
            setFields(prev => prev.map(f => ({ ...f, pests: 0, pest_type: '' })));
            fullReportRef.current = {};
        },
        duration: 50
    });

    droneTourPath.forEach(fieldId => {
      droneTimeline.push({
        action: () => {
          setDroneTarget(createTarget(fieldId, 'drone'));
          setDroneAction(`[COLETA] Escaneando Talhão ${fieldId}...`);
        },
        duration: TIME_PER_FIELD
      });
    });

    droneTimeline.push({
      action: () => {
        setDroneTarget(createTarget('home', 'drone'));
        setDroneAction('Coleta finalizada. Retornando à base para análise.');
      },
      duration: TIME_TO_RETURN
    });

    droneTimeline.push({
      action: () => {
        startActionPhase();
      },
      duration: 1000
    });

    runTimeline(droneTimeline);
  };

  startActionPhase = async () => {
    await fetchReports();
    const TIME_PER_FIELD = 28000;
    const TIME_TO_RETURN = 5000;
    const actionTimeline = [];
    const fieldsToAction = Object.values(fullReportRef.current).filter(order => order.worker_task || order.tractor_task);

    actionTimeline.push({
        action: () => {
            setDroneAction('Análise de dados concluída. Exibindo talhões com pragas.');
            setFields(prev => prev.map(field => {
                const pestInfo = fullReportRef.current[field.id];
                if (pestInfo && (pestInfo.worker_task || pestInfo.tractor_task)) {
                    return { ...field, pests: (pestInfo.infestation_level * 100).toFixed(1), pest_type: pestInfo.pest_detected };
                }
                return field;
            }));
        },
        duration: 2000 
    });

    if (fieldsToAction.length === 0) {
      setPersonAction('Análise concluída. Nenhuma ação de campo necessária.');
      setTractorAction('Nenhuma ação de campo necessária.');
      actionTimeline.push({ action: () => startSimulationCycle(), duration: 5000 });
    } else {
      fieldsToAction.forEach(order => {
        const { field, worker_task, tractor_task } = order;
        
        actionTimeline.push({
          action: () => {
            if (worker_task) {
              setPersonAction(`[AÇÃO] ${worker_task.agent} no Talhão ${field}`);
              setPersonTarget(createTarget(field, 'person'));
            }
            if (tractor_task) {
              setTractorAction(`[AÇÃO] ${tractor_task.agent} no Talhão ${field}`);
              setTractorTarget(createTarget(field, 'tractor'));
            }
          },
          duration: TIME_PER_FIELD
        });

        actionTimeline.push({
            action: () => {
                setFields(prev => prev.map(f => f.id === field ? { ...f, pests: 0, pest_type: '' } : f));
                if (worker_task) setPersonAction(`Ação no Talhão ${field} concluída.`);
                if (tractor_task) setTractorAction(`Ação no Talhão ${field} concluída.`);
            },
            duration: 50
        });
      });

      actionTimeline.push({
        action: () => {
          setPersonTarget(createTarget('base', 'person'));
          setTractorTarget(createTarget('parking', 'tractor'));
          setPersonAction('Ações finalizadas. Retornando à base.');
          setTractorAction('Ações finalizadas. Retornando à base.');
        },
        duration: TIME_TO_RETURN
      });

      actionTimeline.push({ action: () => startSimulationCycle(), duration: 5000 });
    }
    runTimeline(actionTimeline);
  };

  useEffect(() => {
    fetchReports(); 
    function connect() {
      ws.current = new WebSocket('ws://localhost:8000/ws');
      ws.current.onopen = () => { console.log("WebSocket conectado"); startSimulationCycle(); };
      ws.current.onclose = () => setTimeout(connect, 5000);
      ws.current.onmessage = (event) => {
        const data = JSON.parse(event.data);
        fullReportRef.current[data.field] = data;
        setPestData(prev => [...prev, data]);
      };
      ws.current.onerror = (err) => { console.error("Erro no WebSocket:", err); ws.current.close(); };
    }
    connect();
    return () => {
      ws.current && ws.current.close();
      if (timelineTimeoutRef.current) clearTimeout(timelineTimeoutRef.current);
    };
  }, []);

  // Opções de configuração para os gráficos com fontes maiores
  const chartOptions = {
    maintainAspectRatio: false,
    plugins: {
        legend: {
            labels: { font: { size: 25 } }
        },
        title: {
            display: true,
            font: { size: 25 }
        },
        tooltip: {
            titleFont: { size: 24 },
            bodyFont: { size: 26 },
            footerFont: { size: 25 }
        }
    },
    scales: {
        y: { ticks: { font: { size: 18 } } },
        x: { ticks: { font: { size: 18 } } }
    }
  };

  return (
    <div className="bg-gray-100 min-h-screen font-sans">
      <header className="bg-green-800 text-white p-4 shadow-md flex justify-between items-center">
        <h1 className="text-2xl font-bold">Painel de Monitoramento de Sorgo</h1>
        <div>
          <button onClick={() => setView('painel')} className={`px-6 py-4 rounded-md text-sm font-medium ${view === 'painel' ? 'bg-white text-green-800' : 'bg-green-700 hover:bg-green-600'}`}>Painel</button>
          <button onClick={() => { setView('relatorio'); fetchReports(); }} className={`ml-2 px-6 py-4 rounded-md text-sm font-medium ${view === 'relatorio' ? 'bg-white text-green-800' : 'bg-green-700 hover:bg-green-600'}`}>Dashboard</button>
        </div>
      </header>

      {view === 'painel' ? (
        <main className="p-6">
          <div className="mb-6">
            <FieldVisualization 
              fields={fields}
              dronePos={dronePos}
              personPos={personPos}
              tractorPos={tractorPos}
              droneAction={droneAction}
              personAction={personAction}
              tractorAction={tractorAction}
            />
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
            <div className="bg-white p-6 rounded-xl shadow-lg">
              <h2 className="text-xl font-bold mb-4 text-gray-800">🚁 Status do Drone</h2>
              <p className="text-gray-700 font-semibold">{droneAction}</p>
            </div>
            <div className="bg-white p-6 rounded-xl shadow-lg">
              <h2 className="text-xl font-bold mb-4 text-gray-800">👨‍🌾 Status do Trabalhador</h2>
              <p className="text-gray-700 font-semibold">{personAction}</p>
            </div>
            <div className="bg-white p-6 rounded-xl shadow-lg">
              <h2 className="text-xl font-bold mb-4 text-gray-800">🚜 Status do Trator</h2>
              <p className="text-gray-700 font-semibold">{tractorAction}</p>
            </div>
          </div>
           <div className="bg-white p-6 rounded-xl shadow-lg">
                <h2 className="text-xl font-bold mb-4 text-gray-800">Nível Médio de Infestação por Talhão</h2>
                <div className="h-80">
                    {chartData?.infestationByField ? <Bar data={chartData.infestationByField} options={{...chartOptions, plugins: {...chartOptions.plugins, title: { display: false }}}} /> : <p className="text-center pt-20 text-gray-500">Carregando dados do gráfico...</p>}
                </div>
            </div>
        </main>
      ) : (
        <main className="p-6">
            <div className="flex justify-between items-center mb-6">
                <h2 className="text-3xl font-bold text-gray-800">Dashboard Analítico</h2>
                <div className="flex space-x-4">
                    <button
                        onClick={fetchReports}
                        className="bg-blue-600 text-white rounded px-4 py-2 hover:bg-blue-700 disabled:bg-gray-400"
                        disabled={loadingReports}
                    >
                        {loadingReports ? 'Atualizando...' : 'Atualizar Dados'}
                    </button>
                    <button
                        onClick={handleExportToExcel}
                        className="bg-green-700 text-white rounded px-4 py-2 hover:bg-green-800"
                    >
                        Exportar para Excel
                    </button>
                </div>
            </div>
            {chartData ? (
                <div className="grid grid-cols-1 gap-8">
                    <ChartCard>
                        <Pie data={chartData.pestDistribution} options={{...chartOptions, plugins: {...chartOptions.plugins, title: {...chartOptions.plugins.title, text: 'Distribuição de Pragas'}}}} />
                    </ChartCard>
                    <ChartCard>
                        <Bar data={chartData.severity} options={{...chartOptions, plugins: {...chartOptions.plugins, legend: {display: false}, title: {...chartOptions.plugins.title, text: 'Contagem por Severidade'}}}} />
                    </ChartCard>
                    <ChartCard>
                        <Doughnut data={chartData.actionMethods} options={{...chartOptions, plugins: {...chartOptions.plugins, title: {...chartOptions.plugins.title, text: 'Métodos de Controle Utilizados'}}}} />
                    </ChartCard>
                </div>
            ) : (
                <p className="text-center text-gray-500 mt-12">
                    {loadingReports ? 'Carregando dados...' : 'Nenhum dado de relatório para analisar. Execute a simulação para gerar dados.'}
                </p>
            )}
        </main>
      )}
    </div>
  );
};

export default App;
