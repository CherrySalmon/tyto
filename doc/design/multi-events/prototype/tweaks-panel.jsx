// Tweaks panel — explore entry-point variants and a few visual knobs
function TweaksPanel({ tweaks, setTweaks, visible, onClose }) {
  if (!visible) return null;
  const Row = ({ label, children }) => (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10, gap: 10 }}>
      <label style={{ fontSize: 12, color: '#606266', fontWeight: 500 }}>{label}</label>
      <div>{children}</div>
    </div>
  );
  return (
    <div style={{
      position: 'fixed', bottom: 20, right: 20, zIndex: 200,
      background: '#fff', border: '1px solid #dcdfe6', borderRadius: 6,
      padding: 14, width: 280,
      boxShadow: '0 8px 24px rgba(0,0,0,0.14)',
      fontFamily: 'Inter, system-ui, sans-serif',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
        <div style={{ fontSize: 13, fontWeight: 700, color: '#303133' }}>Tweaks</div>
        <button onClick={onClose} style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: '#909399', fontSize: 16 }}>×</button>
      </div>
      <Row label="Auto-open modal">
        <input type="checkbox" checked={tweaks.autoOpen} onChange={e => setTweaks({ ...tweaks, autoOpen: e.target.checked })} />
      </Row>
      <Row label="Start on step">
        <select value={tweaks.startStep} onChange={e => setTweaks({ ...tweaks, startStep: parseInt(e.target.value, 10) })}
          style={{ padding: '4px 8px', fontSize: 12, borderRadius: 3, border: '1px solid #dcdfe6' }}>
          <option value={1}>1 · Dates</option>
          <option value={2}>2 · Refine (pre-filled)</option>
        </select>
      </Row>
      <div style={{ fontSize: 11, color: '#909399', marginTop: 8, lineHeight: 1.4 }}>
        Toggle these to try different entry points. Open the modal to see the full flow.
      </div>
    </div>
  );
}

Object.assign(window, { TweaksPanel });
