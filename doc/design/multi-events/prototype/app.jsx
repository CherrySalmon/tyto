// App root — wires browser chrome + Tyto page + modal + tweaks

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "autoOpen": true,
  "startStep": 1
}/*EDITMODE-END*/;

function App() {
  const [tweaks, setTweaks] = React.useState(TWEAK_DEFAULTS);
  const [tweaksVisible, setTweaksVisible] = React.useState(false);
  const [modalOpen, setModalOpen] = React.useState(tweaks.autoOpen);
  const [createdEvents, setCreatedEvents] = React.useState([]);
  const [toast, setToast] = React.useState(null);

  // Edit-mode protocol
  React.useEffect(() => {
    const onMsg = e => {
      if (e.data?.type === '__activate_edit_mode') setTweaksVisible(true);
      if (e.data?.type === '__deactivate_edit_mode') setTweaksVisible(false);
    };
    window.addEventListener('message', onMsg);
    window.parent.postMessage({ type: '__edit_mode_available' }, '*');
    return () => window.removeEventListener('message', onMsg);
  }, []);

  const updateTweaks = next => {
    setTweaks(next);
    window.parent.postMessage({ type: '__edit_mode_set_keys', edits: next }, '*');
  };

  const openBulk = () => setModalOpen(true);
  const openSingle = () => setModalOpen(true); // same modal handles single case

  const onConfirm = events => {
    setCreatedEvents(prev => [...prev, ...events.map(e => {
      const loc = window.LOCATIONS.find(l => l.id === e.location_id);
      const d = new Date(e.start_at);
      return {
        name: e.name,
        location: loc?.name || '—',
        date: `${d.toLocaleDateString('en-US', { month: 'short', day: '2-digit' })}, ${e.start_at.slice(11, 16)}–${e.end_at.slice(11, 16)}`,
      };
    })]);
    setModalOpen(false);
    setToast(`✓ Created ${events.length} event${events.length !== 1 ? 's' : ''}`);
    setTimeout(() => setToast(null), 2800);
  };

  return (
    <div style={{ position: 'relative', width: 1280, height: 860, borderRadius: 10, overflow: 'hidden', boxShadow: '0 24px 80px rgba(0,0,0,0.28)' }}>
      <ChromeWindow
        tabs={[{ title: 'Tyto — Neural Networks' }]}
        url="tyto.app/course/42/attendance"
        width={1280} height={860}>
        <div style={{ position: 'relative', minHeight: '100%' }}>
          <TytoPage
            onOpenBulk={openBulk}
            onOpenSingle={openSingle}
            entryPointStyle={tweaks.entryPointStyle}
            tweakedEvents={createdEvents}
          />
          <CreateEventsModal
            open={modalOpen}
            onClose={() => setModalOpen(false)}
            onConfirm={onConfirm}
            initialStep={tweaks.startStep}
          />
          {toast && (
            <div style={{
              position: 'absolute', top: 100, left: '50%', transform: 'translateX(-50%)',
              background: '#67c23a', color: '#fff', padding: '10px 18px',
              borderRadius: 4, fontSize: 14, fontWeight: 500,
              boxShadow: '0 4px 16px rgba(0,0,0,0.15)',
              animation: 'fadeIn 200ms ease',
            }}>{toast}</div>
          )}
        </div>
      </ChromeWindow>

      <TweaksPanel
        tweaks={tweaks}
        setTweaks={updateTweaks}
        visible={tweaksVisible}
        onClose={() => setTweaksVisible(false)}
      />

      <style>{`
        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(-4px) translateX(-50%); }
          to { opacity: 1; transform: translateY(0) translateX(-50%); }
        }
      `}</style>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
