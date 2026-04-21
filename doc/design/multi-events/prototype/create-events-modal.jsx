// Create Events Modal — single + two-step bulk flow
// Single: one modal (Name / Location / Date / Start / End — matches current Tyto form)
// Bulk toggle → step 1 (dates + pattern + shared fields) → step 2 (wide spreadsheet review)

const LOCATIONS = [
  { id: 1, name: 'DeBartolo 101' },
  { id: 2, name: 'DeBartolo 102' },
  { id: 3, name: 'Fitzpatrick 356' },
  { id: 4, name: 'Jordan Hall 105' },
  { id: 5, name: 'Online (Zoom)' },
];

const pad2 = n => String(n).padStart(2, '0');
const fmtDateISO = d => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
const fmtDateShort = d => d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
const fmtDateMed = d => d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
const sameDay = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

// ---------- Calendar ----------
function Calendar({ monthOffset, selected, onToggle, existingDates = [] }) {
  const today = new Date();
  const base = new Date(today.getFullYear(), today.getMonth() + monthOffset, 1);
  const year = base.getFullYear();
  const month = base.getMonth();
  const firstDow = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const monthName = base.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });

  const cells = [];
  for (let i = 0; i < firstDow; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(new Date(year, month, d));
  while (cells.length % 7 !== 0) cells.push(null);

  return (
    <div style={{ background: '#fff', border: '1px solid #e4e7ed', borderRadius: 4, padding: 10 }}>
      <div style={{ textAlign: 'center', fontWeight: 600, fontSize: 13, color: '#606266', marginBottom: 6 }}>
        {monthName}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 1 }}>
        {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d, i) => (
          <div key={i} style={{ textAlign: 'center', fontSize: 10, color: '#909399', padding: '3px 0', fontWeight: 600 }}>{d}</div>
        ))}
        {cells.map((c, i) => {
          if (!c) return <div key={i} />;
          const iso = fmtDateISO(c);
          const isSelected = selected.includes(iso);
          const isToday = sameDay(c, today);
          const isExisting = existingDates.includes(iso);
          const isWeekend = c.getDay() === 0 || c.getDay() === 6;
          return (
            <div key={i} onClick={() => onToggle(iso)} style={{
              textAlign: 'center', padding: '6px 0', fontSize: 12,
              borderRadius: 3, cursor: 'pointer',
              background: isSelected ? '#EAA034' : isExisting ? '#fdf6ec' : 'transparent',
              color: isSelected ? '#fff' : isWeekend ? '#c0c4cc' : '#303133',
              fontWeight: isSelected ? 600 : isToday ? 700 : 400,
              border: isToday && !isSelected ? '1px solid #EAA034' : '1px solid transparent',
              position: 'relative', transition: 'background 120ms',
            }}
            onMouseEnter={e => { if (!isSelected) e.currentTarget.style.background = '#f5f7fa'; }}
            onMouseLeave={e => { if (!isSelected) e.currentTarget.style.background = isExisting ? '#fdf6ec' : 'transparent'; }}
            >
              {c.getDate()}
              {isExisting && !isSelected && (
                <div style={{ position: 'absolute', bottom: 1, left: '50%', transform: 'translateX(-50%)', width: 3, height: 3, borderRadius: '50%', background: '#e6a23c' }} />
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ---------- Quick pick chips ----------
function QuickPick({ onApply }) {
  const buttons = [
    { label: 'Every Mon', dows: [1], weeks: 8 },
    { label: 'Every Wed', dows: [3], weeks: 8 },
    { label: 'Every Fri', dows: [5], weeks: 8 },
    { label: 'Mon + Wed', dows: [1, 3], weeks: 8 },
    { label: 'Tue + Thu', dows: [2, 4], weeks: 8 },
  ];
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
      {buttons.map((b, i) => (
        <button key={i} onClick={() => onApply(b)} style={{
          background: '#fff', border: '1px dashed #c0c4cc', borderRadius: 14,
          padding: '3px 10px', fontSize: 11, color: '#606266', cursor: 'pointer',
          fontFamily: 'inherit',
        }}
        onMouseEnter={e => { e.currentTarget.style.borderColor = '#409eff'; e.currentTarget.style.color = '#409eff'; }}
        onMouseLeave={e => { e.currentTarget.style.borderColor = '#c0c4cc'; e.currentTarget.style.color = '#606266'; }}
        >{b.label}</button>
      ))}
    </div>
  );
}

// ---------- Element Plus icons (inlined from @element-plus/icons-vue) ----------
// All use 1024x1024 viewBox with currentColor fill — matches the real Tyto app
const EP = {
  ArrowUp: 'M872.25 348.31c-9.18 0-18.36-3.5-25.36-10.5L512 3.92 177.11 338.81c-14 14-36.71 14-50.72 0s-14-36.71 0-50.72L486.64 -71.4c14-14 36.71-14 50.72 0l360.25 360.25c14 14 14 36.71 0 50.72-7 7-16.18 10.5-25.36 10.5z',
  ArrowDown: 'M512 750.08a35.79 35.79 0 0 1-25.36-10.5L126.39 379.33c-14-14-14-36.71 0-50.72s36.71-14 50.72 0L512 663.5l334.89-334.89c14-14 36.71-14 50.72 0s14 36.71 0 50.72L537.36 739.58a35.79 35.79 0 0 1-25.36 10.5z',
  Close: 'M195.2 195.2a64 64 0 0 1 90.5 0L512 421.5l226.3-226.3a64 64 0 0 1 90.51 90.5L602.5 512l226.31 226.3a64 64 0 0 1-90.51 90.51L512 602.5 285.7 828.81a64 64 0 0 1-90.5-90.51L421.5 512 195.2 285.7a64 64 0 0 1 0-90.5z',
  Warning: 'M512 64a448 448 0 1 1 0 896 448 448 0 0 1 0-896zm0 192a38.4 38.4 0 0 0-38.4 38.4v256a38.4 38.4 0 0 0 76.8 0v-256A38.4 38.4 0 0 0 512 256zm0 448a51.2 51.2 0 1 0 0 102.4 51.2 51.2 0 0 0 0-102.4z',
  Location: 'M512 928c-39.936 0-74.304-22.976-85.568-57.984L287.296 568.384a384 384 0 1 1 449.408 0L597.568 870.016C586.24 905.024 551.936 928 512 928zm0-256a192 192 0 1 0 0-384 192 192 0 0 0 0 384z',
  Clock: 'M512 64a448 448 0 1 1 0 896 448 448 0 0 1 0-896zm0 64a384 384 0 1 0 0 768 384 384 0 0 0 0-768zm-32 128a32 32 0 0 1 32 32v224h160a32 32 0 1 1 0 64H480a32 32 0 0 1-32-32V288a32 32 0 0 1 32-32z',
  ArrowLeft: 'M609.408 149.376L277.76 489.6a32 32 0 0 0 0 44.672l331.648 340.352a29.12 29.12 0 0 0 41.728 0 30.592 30.592 0 0 0 0-42.752L339.264 511.936l311.872-319.872a30.592 30.592 0 0 0 0-42.688 29.12 29.12 0 0 0-41.728 0z',
  ArrowRight: 'M340.864 149.312a30.592 30.592 0 0 0 0 42.752L652.736 512 340.864 831.872a30.592 30.592 0 0 0 0 42.752 29.12 29.12 0 0 0 41.728 0L714.24 534.336a32 32 0 0 0 0-44.672L382.592 149.376a29.12 29.12 0 0 0-41.728 0z',
  Download: 'M544 864V672h128L512 480 352 672h128v192H320a160 160 0 0 1-160-160 160 160 0 0 1 160-160h384a160 160 0 0 1 160 160 160 160 0 0 1-160 160H544z',
};

function Icon({ name, size = 14, color, style }) {
  const d = EP[name];
  if (!d) return null;
  return (
    <svg viewBox="0 0 1024 1024" width={size} height={size}
         fill={color || 'currentColor'} aria-hidden
         style={{ display: 'inline-block', verticalAlign: '-0.15em', flexShrink: 0, ...style }}>
      <path d={d} />
    </svg>
  );
}

// ---------- Form primitives ----------
function Field({ label, children, hint, labelWidth = 95, required }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, marginBottom: 14 }}>
      <label style={{ flex: `0 0 ${labelWidth}px`, fontSize: 14, color: '#606266', textAlign: 'right', paddingTop: 8, fontWeight: 500 }}>
        {required && <span style={{ color: '#f56c6c', marginRight: 4 }}>*</span>}
        {label}
      </label>
      <div style={{ flex: 1, minWidth: 0 }}>
        {children}
        {hint && <div style={{ fontSize: 12, color: '#909399', marginTop: 4 }}>{hint}</div>}
      </div>
    </div>
  );
}

function Input({ value, onChange, placeholder, style, width, type, invalid, step }) {
  const border = invalid ? '#f56c6c' : '#dcdfe6';
  const bg = invalid ? '#fef6f6' : undefined;
  return (
    <input type={type || 'text'} value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder}
      step={step}
      style={{ width: width || '100%', padding: '6px 11px', fontSize: 14, border: `1px solid ${border}`, borderRadius: 4, outline: 'none', color: '#303133', fontFamily: 'inherit', background: bg, transition: 'border 120ms, background 120ms', ...style }}
      onFocus={e => e.currentTarget.style.borderColor = '#409eff'}
      onBlur={e => e.currentTarget.style.borderColor = border}
    />
  );
}

function Select({ value, onChange, options, placeholder, width, invalid }) {
  const border = invalid ? '#f56c6c' : '#dcdfe6';
  const bg = invalid ? '#fef6f6' : '#fff';
  return (
    <select value={value} onChange={e => onChange(e.target.value)}
      style={{ width: width || '100%', padding: '7px 11px', fontSize: 14, border: `1px solid ${border}`, borderRadius: 4, outline: 'none', color: '#303133', background: bg, fontFamily: 'inherit', cursor: 'pointer' }}>
      {placeholder && <option value="">{placeholder}</option>}
      {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
    </select>
  );
}

function DateInput({ value, onChange, placeholder, invalid }) {
  return <Input type="date" value={value} onChange={onChange} placeholder={placeholder} width={180} invalid={invalid} />;
}

// Combined Date + 24-hour Time input. Value: 'YYYY-MM-DDTHH:MM'
function DateTimeInput({ value, onChange, invalid }) {
  const [d, t] = (value || '').split('T');
  const setDate = nd => onChange(nd ? `${nd}T${t || ''}` : '');
  const setTime = nt => onChange(`${d || ''}T${nt || ''}`);
  return (
    <div style={{ display: 'inline-flex', gap: 8 }}>
      <Input type="date" value={d || ''} onChange={setDate} width={170} invalid={invalid && !d} />
      <TimeInput value={t || ''} onChange={setTime} invalid={invalid && !t} width={110} />
    </div>
  );
}

// 24-hour HH:MM time input — avoids browser-locale AM/PM on native type="time"
function TimeInput({ value, onChange, invalid, width = 140 }) {
  const border = invalid ? '#f56c6c' : '#dcdfe6';
  const bg = invalid ? '#fef6f6' : undefined;
  const [local, setLocal] = React.useState(value || '');
  React.useEffect(() => { setLocal(value || ''); }, [value]);

  const format = raw => {
    const d = raw.replace(/\D/g, '').slice(0, 4);
    if (d.length <= 2) return d;
    return d.slice(0, 2) + ':' + d.slice(2);
  };
  const commit = raw => {
    const m = raw.match(/^(\d{1,2}):?(\d{0,2})$/);
    if (!m) { onChange(''); return; }
    let h = parseInt(m[1], 10); let mm = parseInt(m[2] || '0', 10);
    if (isNaN(h) || h > 23) h = 0;
    if (isNaN(mm) || mm > 59) mm = 0;
    const out = String(h).padStart(2, '0') + ':' + String(mm).padStart(2, '0');
    setLocal(out);
    onChange(out);
  };
  // Detect table-cell usage ("100%" or similar) — use no border / flat style
  const isCell = width === '100%';
  const style = isCell
    ? { width: '100%', padding: '6px 8px', fontSize: 13, border: '1px solid transparent', borderRadius: 3, outline: 'none', color: '#303133', fontFamily: 'inherit', background: 'transparent', fontVariantNumeric: 'tabular-nums' }
    : { width, padding: '6px 11px', fontSize: 14, border: `1px solid ${border}`, borderRadius: 4, outline: 'none', color: '#303133', fontFamily: 'inherit', background: bg, transition: 'border 120ms', fontVariantNumeric: 'tabular-nums' };
  return (
    <input type="text" inputMode="numeric" value={local} placeholder="--:--"
      onChange={e => setLocal(format(e.target.value))}
      onBlur={e => { e.currentTarget.style.borderColor = isCell ? 'transparent' : border; e.target.value ? commit(e.target.value) : onChange(''); }}
      style={style}
      onFocus={e => e.currentTarget.style.borderColor = '#409eff'}
    />
  );
}

// ---------- Spreadsheet ----------
const cellStyle = { padding: '4px 6px', borderBottom: '1px solid #f2f4f7', verticalAlign: 'middle' };

function CellInput({ value, onChange, placeholder, type = 'text', step }) {
  return (
    <input type={type} value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder} step={step}
      style={{ width: '100%', padding: '6px 8px', fontSize: 13, border: '1px solid transparent', borderRadius: 3, outline: 'none', background: 'transparent', fontFamily: 'inherit', color: '#303133' }}
      onFocus={e => { e.currentTarget.style.borderColor = '#409eff'; e.currentTarget.style.background = '#fff'; }}
      onBlur={e => { e.currentTarget.style.borderColor = 'transparent'; e.currentTarget.style.background = 'transparent'; }}
    />
  );
}

function CellSelect({ value, onChange, options }) {
  return (
    <select value={value} onChange={e => onChange(e.target.value)}
      style={{ width: '100%', padding: '6px 8px', fontSize: 13, border: '1px solid transparent', borderRadius: 3, outline: 'none', background: 'transparent', color: '#303133', fontFamily: 'inherit', cursor: 'pointer' }}
      onFocus={e => { e.currentTarget.style.borderColor = '#409eff'; e.currentTarget.style.background = '#fff'; }}
      onBlur={e => { e.currentTarget.style.borderColor = 'transparent'; e.currentTarget.style.background = 'transparent'; }}
    >
      <option value="">—</option>
      {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
    </select>
  );
}

function IconBtn({ children, onClick, title, danger }) {
  return (
    <button onClick={onClick} title={title} style={{
      background: 'transparent', border: 'none', cursor: 'pointer',
      color: danger ? '#f56c6c' : '#909399', padding: '2px 6px',
      fontSize: 14, lineHeight: 1, borderRadius: 3, fontFamily: 'inherit',
    }}>{children}</button>
  );
}

function SpreadsheetGrid({ rows, setRows }) {
  const updateRow = (id, patch) => setRows(rs => rs.map(r => r.id === id ? { ...r, ...patch } : r));
  const removeRow = id => setRows(rs => rs.filter(r => r.id !== id));
  const moveRow = (id, dir) => setRows(rs => {
    const i = rs.findIndex(r => r.id === id);
    if (i < 0) return rs;
    const j = i + dir;
    if (j < 0 || j >= rs.length) return rs;
    const copy = [...rs];
    [copy[i], copy[j]] = [copy[j], copy[i]];
    return copy;
  });
  const addRow = () => {
    const last = rows[rows.length - 1];
    const nextDate = last ? addDays(last.date, 7) : fmtDateISO(new Date());
    setRows([...rows, {
      id: Math.random().toString(36).slice(2, 9),
      name: '', date: nextDate,
      locationId: last?.locationId || '', startTime: last?.startTime || '', endTime: last?.endTime || '',
    }]);
  };
  const fillDown = (key) => setRows(rs => {
    if (rs.length === 0) return rs;
    const v = rs[0][key];
    return rs.map(r => ({ ...r, [key]: v }));
  });

  const conflicts = detectConflicts(rows);

  const col = (label, width) => (
    <th style={{ textAlign: 'left', fontSize: 11, fontWeight: 600, letterSpacing: 0.4, textTransform: 'uppercase', color: '#909399', padding: '10px 8px', borderBottom: '1px solid #ebeef5', background: '#fafbfc', position: 'sticky', top: 0, zIndex: 1, width, minWidth: width, whiteSpace: 'nowrap' }}>{label}</th>
  );

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <div style={{ fontSize: 13, color: '#606266' }}>
          <b>{rows.length}</b> event{rows.length !== 1 ? 's' : ''} ready
          {conflicts.length > 0 && (
            <span style={{ marginLeft: 10, color: '#b88230', background: '#fdf6ec', padding: '2px 8px', borderRadius: 10, fontWeight: 500, fontSize: 12 }}>
              <Icon name="Warning" size={12} style={{ marginRight: 4 }} /> {conflicts.length} same-location conflict{conflicts.length !== 1 ? 's' : ''}
            </span>
          )}
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <button onClick={() => fillDown('locationId')} style={fillBtnStyle}>Fill location <Icon name="ArrowDown" size={10} /></button>
          <button onClick={() => fillDown('startTime')} style={fillBtnStyle}>Fill start <Icon name="ArrowDown" size={10} /></button>
          <button onClick={() => fillDown('endTime')} style={fillBtnStyle}>Fill end <Icon name="ArrowDown" size={10} /></button>
        </div>
      </div>

      <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', border: '1px solid #ebeef5', borderRadius: 4 }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
          <thead>
            <tr>{col('#', 32)}{col('Name', 220)}{col('Date', 150)}{col('Location', 200)}{col('Start', 80)}{col('End', 80)}{col('', 100)}</tr>
          </thead>
          <tbody>
            {rows.map((r, i) => {
              const conflict = conflicts.find(c => c.ids.includes(r.id));
              return (
                <tr key={r.id} style={{ background: conflict ? '#fdf6ec' : (i % 2 === 0 ? '#fff' : '#fafbfc') }}>
                  <td style={cellStyle}><span style={{ color: '#909399', fontSize: 12 }}>{i + 1}</span></td>
                  <td style={cellStyle}><CellInput value={r.name} onChange={v => updateRow(r.id, { name: v })} /></td>
                  <td style={cellStyle}><CellInput type="date" value={r.date} onChange={v => updateRow(r.id, { date: v })} /></td>
                  <td style={cellStyle}><CellSelect value={r.locationId} onChange={v => updateRow(r.id, { locationId: v })} options={LOCATIONS.map(l => ({ value: String(l.id), label: l.name }))} /></td>
                  <td style={cellStyle}><TimeInput value={r.startTime} onChange={v => updateRow(r.id, { startTime: v })} width="100%" /></td>
                  <td style={cellStyle}><TimeInput value={r.endTime} onChange={v => updateRow(r.id, { endTime: v })} width="100%" /></td>
                  <td style={{ ...cellStyle, textAlign: 'right', whiteSpace: 'nowrap' }}>
                    {conflict && <span title={conflict.reason} style={{ color: '#b88230', marginRight: 4, cursor: 'help', display: 'inline-flex' }}><Icon name="Warning" size={13} /></span>}
                    <IconBtn title="Move up" onClick={() => moveRow(r.id, -1)}><Icon name="ArrowUp" size={12} /></IconBtn>
                    <IconBtn title="Move down" onClick={() => moveRow(r.id, 1)}><Icon name="ArrowDown" size={12} /></IconBtn>
                    <IconBtn title="Remove" onClick={() => removeRow(r.id)} danger><Icon name="Close" size={12} /></IconBtn>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
        {rows.length === 0 && (
          <div style={{ padding: '32px 20px', textAlign: 'center', color: '#909399', fontSize: 13 }}>
            No events. Add a row manually, or go back to pick dates.
          </div>
        )}
      </div>

      <div style={{ marginTop: 10 }}>
        <button onClick={addRow} style={{ background: '#fff', border: '1px dashed #409eff', color: '#409eff', padding: '5px 12px', borderRadius: 4, fontSize: 12, cursor: 'pointer', fontFamily: 'inherit', fontWeight: 500 }}>+ Add event</button>
      </div>
    </div>
  );
}

const fillBtnStyle = { background: '#fff', border: '1px solid #dcdfe6', color: '#606266', padding: '3px 9px', borderRadius: 4, fontSize: 11, cursor: 'pointer', fontFamily: 'inherit' };

function addDays(iso, n) {
  const d = new Date(iso + 'T00:00');
  d.setDate(d.getDate() + n);
  return fmtDateISO(d);
}

function detectConflicts(rows) {
  const conflicts = [];
  for (let i = 0; i < rows.length; i++) {
    for (let j = i + 1; j < rows.length; j++) {
      const a = rows[i], b = rows[j];
      if (a.date === b.date && a.locationId && a.locationId === b.locationId) {
        const existing = conflicts.find(c => c.ids.includes(a.id) || c.ids.includes(b.id));
        if (existing) {
          if (!existing.ids.includes(a.id)) existing.ids.push(a.id);
          if (!existing.ids.includes(b.id)) existing.ids.push(b.id);
        } else {
          conflicts.push({ ids: [a.id, b.id], reason: `Same location on ${a.date}` });
        }
      }
    }
  }
  return conflicts;
}

function buildName(prefix, format, startNum, i, iso) {
  const p = prefix || '';
  const n = parseInt(startNum || '1', 10) + i;
  if (format === 'pad2') return `${p} ${pad2(n)}`.trim();
  if (format === 'nopad') return `${p} ${n}`.trim();
  if (format === 'date-short') {
    const d = new Date(iso + 'T00:00');
    return `${p} — ${fmtDateShort(d)}`.replace(/^— /, '').trim();
  }
  if (format === 'none') return p;
  return `${p} ${pad2(n)}`.trim();
}

function locName(id) {
  const l = LOCATIONS.find(l => String(l.id) === String(id));
  return l ? l.name : null;
}

// =============================================================
// MODAL
// =============================================================
function CreateEventsModal({ open, onClose, onConfirm }) {
  // 'single' = single-event modal
  // 'bulk-dates' = step 1 of bulk flow
  // 'bulk-review' = step 2 of bulk flow (spreadsheet)
  const [step, setStep] = React.useState('single');

  // Single-event fields (matches real app: name / location / start_at / end_at as datetime)
  const [single, setSingle] = React.useState({ name: '', locationId: '', startAt: '', endAt: '' });

  // Bulk fields
  const [selectedDates, setSelectedDates] = React.useState([]);
  const [prefix, setPrefix] = React.useState('Week');
  const [nameFormat, setNameFormat] = React.useState('pad2');
  const [startNum, setStartNum] = React.useState('8');
  const [sharedLoc, setSharedLoc] = React.useState('');
  const [sharedStart, setSharedStart] = React.useState('');
  const [sharedEnd, setSharedEnd] = React.useState('');
  const [rows, setRows] = React.useState([]);
  const [monthCount, setMonthCount] = React.useState(2);
  const [attempted, setAttempted] = React.useState(false); // show red validation once user tries to proceed
  const calStripRef = React.useRef(null);
  const prevMonthCount = React.useRef(2);

  React.useEffect(() => {
    if (monthCount > prevMonthCount.current && calStripRef.current) {
      const el = calStripRef.current;
      requestAnimationFrame(() => { el.scrollTo({ left: el.scrollWidth, behavior: 'smooth' }); });
    }
    prevMonthCount.current = monthCount;
  }, [monthCount]);

  React.useEffect(() => {
    if (open) {
      setStep('single');
      setSingle({ name: '', locationId: '', startAt: '', endAt: '' });
      setSelectedDates([]);
      setPrefix('Week'); setNameFormat('pad2'); setStartNum('8');
      setSharedLoc(''); setSharedStart(''); setSharedEnd('');
      setRows([]);
      setMonthCount(2);
      setAttempted(false);
    }
  }, [open]);

  // Reset validation when switching steps
  React.useEffect(() => { setAttempted(false); }, [step]);

  const existingISO = React.useMemo(() => (window.EXISTING_EVENTS || []).map(e => {
    const d = new Date(`${e.date.split(',')[0]}, 2025`);
    return fmtDateISO(d);
  }), []);

  const toggleDate = iso => {
    setSelectedDates(ds => (ds.includes(iso) ? ds.filter(d => d !== iso) : [...ds, iso].sort()));
  };

  const applyQuickPick = ({ dows, weeks }) => {
    const base = new Date();
    const picked = new Set(selectedDates);
    for (let w = 0; w < weeks; w++) {
      for (const dow of dows) {
        const offset = (dow - base.getDay() + 7) % 7 + w * 7;
        const d = new Date(base); d.setDate(base.getDate() + offset);
        picked.add(fmtDateISO(d));
      }
    }
    setSelectedDates(Array.from(picked).sort());
  };

  // Enter review: build rows from current step-1 state
  const tryGoToReview = () => {
    if (!bulkStep1Valid) { setAttempted(true); return; }
    setRows(selectedDates.map((d, i) => ({
      id: Math.random().toString(36).slice(2, 9),
      name: buildName(prefix, nameFormat, startNum, i, d),
      date: d, locationId: sharedLoc, startTime: sharedStart, endTime: sharedEnd,
    })));
    setAttempted(false);
    setStep('bulk-review');
  };

  const bulkStep1Valid = selectedDates.length > 0 && sharedLoc && sharedStart && sharedEnd && prefix.trim();
  const canReview = bulkStep1Valid;
  const canConfirmSingle = single.name && single.locationId && /T\d\d:\d\d/.test(single.startAt) && /T\d\d:\d\d/.test(single.endAt);
  const canConfirmBulk = rows.length > 0 && rows.every(r => r.name && r.date && r.startTime && r.endTime);
  const missingInReview = rows.filter(r => !r.startTime || !r.endTime || !r.name).length;

  const confirmSingle = () => {
    if (!canConfirmSingle) { setAttempted(true); return; }
    onConfirm([{
      name: single.name, location_id: parseInt(single.locationId, 10) || null,
      start_at: `${single.startAt}:00`, end_at: `${single.endAt}:00`,
    }]);
  };
  const confirmBulk = () => {
    onConfirm(rows.map(r => ({
      name: r.name, location_id: parseInt(r.locationId, 10) || null,
      start_at: `${r.date}T${r.startTime}:00`, end_at: `${r.date}T${r.endTime}:00`,
    })));
  };

  if (!open) return null;

  // Modal sizing by step
  const modalMaxWidth = step === 'bulk-review' ? 1160 : step === 'bulk-dates' ? 820 : 560;

  return (
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: 20 }}>
      <div style={{
        background: '#fff', borderRadius: 4,
        width: '100%', maxWidth: modalMaxWidth,
        maxHeight: 'calc(100% - 40px)',
        display: 'flex', flexDirection: 'column',
        boxShadow: '0 12px 32px rgba(0,0,0,0.2)',
        transition: 'max-width 220ms ease',
      }}>

        {/* ============== SINGLE ============== */}
        {step === 'single' && (
          <SingleOrDatesHeader title="Create Attendance Event" onClose={onClose} />
        )}
        {step === 'bulk-dates' && (
          <StepHeader step={1} total={2} title="Create Attendance Events" subtitle="Pick dates and shared details" onClose={onClose} />
        )}
        {step === 'bulk-review' && (
          <StepHeader step={2} total={2} title="Create Attendance Events" subtitle="Review &amp; refine each event" onClose={onClose} />
        )}

        {/* ============== BODY ============== */}
        {step === 'single' && (
          <div style={{ flex: 1, overflowY: 'auto', padding: '20px 24px' }}>
            {/* Bulk toggle */}
            <div style={{
              margin: '0 0 18px 0', padding: '12px 14px',
              background: '#fafbfc', border: '1px solid #ebeef5',
              borderRadius: 4,
            }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer', userSelect: 'none' }}>
                <input type="checkbox" checked={false} onChange={() => setStep('bulk-dates')}
                  style={{ width: 16, height: 16, accentColor: '#409eff', cursor: 'pointer' }} />
                <span style={{ fontSize: 14, fontWeight: 600, color: '#303133' }}>Create multiple at once</span>
                <span style={{ fontSize: 12, color: '#909399' }}>
                  — pick several dates sharing a location and time
                </span>
              </label>
            </div>

            <Field label="Name" required>
              <Input value={single.name} onChange={v => setSingle(s => ({ ...s, name: v }))} placeholder="e.g. Week 08 Lecture" invalid={attempted && !single.name} />
            </Field>
            <Field label="Location" required>
              <Select value={single.locationId} onChange={v => setSingle(s => ({ ...s, locationId: v }))} placeholder="Select" options={LOCATIONS.map(l => ({ value: String(l.id), label: l.name }))} invalid={attempted && !single.locationId} />
            </Field>
            <Field label="Start" required>
              <DateTimeInput value={single.startAt} onChange={v => setSingle(s => ({ ...s, startAt: v }))} invalid={attempted && !/T\d\d:\d\d/.test(single.startAt)} />
            </Field>
            <Field label="End" required>
              <DateTimeInput value={single.endAt} onChange={v => setSingle(s => ({ ...s, endAt: v }))} invalid={attempted && !/T\d\d:\d\d/.test(single.endAt)} />
            </Field>
          </div>
        )}

        {step === 'bulk-dates' && (
          <div style={{ flex: 1, overflowY: 'auto', padding: '20px 24px' }}>

            {/* Bulk toggle (checked) */}
            <div style={{
              margin: '0 0 16px 0', padding: '12px 14px',
              background: '#fffaf0', border: '1px solid #f0d4a8',
              borderRadius: 4,
            }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer', userSelect: 'none' }}>
                <input type="checkbox" checked={true} onChange={() => setStep('single')}
                  style={{ width: 16, height: 16, accentColor: '#409eff', cursor: 'pointer' }} />
                <span style={{ fontSize: 14, fontWeight: 600, color: '#303133' }}>Create multiple at once</span>
                <span style={{ fontSize: 12, color: '#909399' }}>
                  — uncheck to create a single event
                </span>
              </label>
            </div>

            {/* Name pattern */}
            <div style={panelStyle}>
              <div style={sectionLabel}>Name pattern <span style={{ color: '#f56c6c', fontWeight: 400, marginLeft: 4 }}>*</span></div>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 8, flexWrap: 'wrap' }}>
                <Input value={prefix} onChange={setPrefix} placeholder="Week" width={140} invalid={attempted && !prefix.trim()} />
                <Select value={nameFormat} onChange={setNameFormat} width={150}
                  options={[
                    { value: 'pad2', label: '→ 01, 02, 03 …' },
                    { value: 'nopad', label: '→ 1, 2, 3 …' },
                    { value: 'date-short', label: '→ Aug 26' },
                    { value: 'none', label: '(no suffix)' },
                  ]} />
                {(nameFormat === 'pad2' || nameFormat === 'nopad') && (
                  <>
                    <span style={{ fontSize: 12, color: '#909399' }}>starting at</span>
                    <Input value={startNum} onChange={setStartNum} placeholder="8" width={60} />
                  </>
                )}
                <span style={{ fontSize: 12, color: '#909399', marginLeft: 'auto' }}>
                  Preview: <b style={{ color: '#303133' }}>{buildName(prefix, nameFormat, startNum, 0, selectedDates[0] || fmtDateISO(new Date()))}</b>
                  {selectedDates.length > 1 && <>, {buildName(prefix, nameFormat, startNum, 1, selectedDates[1])}</>}
                  {selectedDates.length > 2 && <>, {buildName(prefix, nameFormat, startNum, 2, selectedDates[2])}…</>}
                </span>
              </div>
              <div style={{ fontSize: 11, color: '#909399', marginTop: 8 }}>You can edit any individual name on the next step.</div>
            </div>

            {/* Shared defaults */}
            <div style={panelStyle}>
              <div style={sectionLabel}>Shared details</div>
              <div style={{ marginTop: 10 }}>
                <Field label="Location" required>
                  <Select value={sharedLoc} onChange={setSharedLoc} placeholder="Select" options={LOCATIONS.map(l => ({ value: String(l.id), label: l.name }))} invalid={attempted && !sharedLoc} />
                </Field>
                <div style={{ display: 'flex', gap: 16 }}>
                  <Field label="Start time" required>
                    <TimeInput value={sharedStart} onChange={setSharedStart} invalid={attempted && !sharedStart} />
                  </Field>
                  <Field label="End time" labelWidth={80} required>
                    <TimeInput value={sharedEnd} onChange={setSharedEnd} invalid={attempted && !sharedEnd} />
                  </Field>
                </div>
                <div style={{ fontSize: 11, color: '#909399', marginTop: -6, marginLeft: 107 }}>
                  These apply to every date. You can override individual events on the next step.
                </div>
              </div>
            </div>

            {/* Calendar strip */}
            <div style={{ ...panelStyle, ...(attempted && selectedDates.length === 0 ? { border: '1px solid #f56c6c', background: '#fef6f6' } : {}) }}>
              <div style={{ ...sectionLabel, marginBottom: 10, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span>
                  <span style={{ color: '#f56c6c', fontWeight: 400, marginRight: 4 }}>*</span>
                  Dates <span style={{ fontWeight: 400, color: '#909399', marginLeft: 6, textTransform: 'none', letterSpacing: 0 }}>· click to toggle · scroll →</span>
                </span>
                <div style={{ display: 'flex', gap: 6 }}>
                  {monthCount > 2 && (
                    <button onClick={() => setMonthCount(n => Math.max(2, n - 1))}
                      style={{ fontSize: 12, color: '#909399', background: 'transparent', border: '1px solid #dcdfe6', borderRadius: 3, padding: '4px 10px', cursor: 'pointer', fontWeight: 500, fontFamily: 'inherit' }}>
                      − Remove
                    </button>
                  )}
                  <button onClick={() => setMonthCount(n => n + 1)}
                    style={{ fontSize: 12, color: '#409eff', background: '#fff', border: '1px solid #409eff', borderRadius: 3, padding: '4px 10px', cursor: 'pointer', fontWeight: 600, fontFamily: 'inherit' }}>
                    + Add month
                  </button>
                </div>
              </div>
              <div ref={calStripRef} style={{
                display: 'flex', gap: 10, marginBottom: 10,
                overflowX: 'auto', overflowY: 'hidden',
                paddingBottom: 8, scrollBehavior: 'smooth',
                scrollbarWidth: 'thin', scrollbarColor: '#dcdfe6 transparent',
              }}>
                {Array.from({ length: monthCount }).map((_, i) => (
                  <div key={i} style={{ flex: '0 0 calc(50% - 5px)', minWidth: 260 }}>
                    <Calendar monthOffset={i} selected={selectedDates} onToggle={toggleDate} existingDates={existingISO} />
                  </div>
                ))}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                <span style={{ fontSize: 11, fontWeight: 600, color: '#606266' }}>Quick pick:</span>
                <QuickPick onApply={applyQuickPick} />
                <span style={{ fontSize: 11, color: '#909399', display: 'inline-flex', alignItems: 'center', gap: 4, marginLeft: 'auto' }}>
                  <span style={{ display: 'inline-block', width: 7, height: 7, borderRadius: 4, background: '#fdf6ec', border: '1px solid #e6a23c' }} />
                  existing event
                </span>
                {selectedDates.length > 0 && (
                  <button onClick={() => setSelectedDates([])}
                    style={{ background: 'transparent', border: 'none', color: '#409eff', fontSize: 11, cursor: 'pointer', fontFamily: 'inherit' }}>Clear</button>
                )}
              </div>
            </div>
          </div>
        )}

        {step === 'bulk-review' && (
          <div style={{ flex: 1, overflow: 'hidden', padding: '16px 24px 0', display: 'flex', flexDirection: 'column' }}>
            {/* Summary chip */}
            <div style={{
              display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap',
              padding: '10px 14px', background: '#fafbfc', border: '1px solid #ebeef5',
              borderRadius: 4, marginBottom: 14, fontSize: 13, color: '#606266',
            }}>
              <span><b style={{ color: '#303133' }}>{selectedDates.length}</b> date{selectedDates.length !== 1 ? 's' : ''}</span>
              <span style={{ color: '#dcdfe6' }}>·</span>
              <span>Pattern: <b style={{ color: '#303133' }}>{buildName(prefix, nameFormat, startNum, 0, selectedDates[0] || fmtDateISO(new Date()))}</b> …</span>
              {sharedLoc && <>
                <span style={{ color: '#dcdfe6' }}>·</span>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><Icon name="Location" size={12} /> {locName(sharedLoc)}</span>
              </>}
              {sharedStart && sharedEnd && <>
                <span style={{ color: '#dcdfe6' }}>·</span>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><Icon name="Clock" size={12} /> {sharedStart}–{sharedEnd}</span>
              </>}
              <button onClick={() => setStep('bulk-dates')}
                style={{ marginLeft: 'auto', background: 'transparent', border: 'none', color: '#409eff', fontSize: 12, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>
                <Icon name="ArrowLeft" size={11} /> Back to edit
              </button>
            </div>
            <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column', paddingBottom: 16 }}>
              <SpreadsheetGrid rows={rows} setRows={setRows} />
            </div>
          </div>
        )}

        {/* ============== FOOTER ============== */}
        {step === 'single' && (
          <div style={footerStyle}>
            <div style={{ fontSize: 13, color: attempted && !canConfirmSingle ? '#c45656' : '#606266' }}>
              {canConfirmSingle
                ? 'Ready to create'
                : attempted
                  ? (() => {
                      const miss = [];
                      if (!single.name) miss.push('name');
                      if (!single.locationId) miss.push('location');
                      if (!/T\d\d:\d\d/.test(single.startAt)) miss.push('start');
                      if (!/T\d\d:\d\d/.test(single.endAt)) miss.push('end');
                      return <>Missing: <b>{miss.join(', ')}</b></>;
                    })()
                  : 'Fill in required fields'}
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button onClick={onClose} style={btnSecondary}>Cancel</button>
              <button onClick={confirmSingle}
                style={canConfirmSingle ? btnPrimary : btnPrimaryDisabled}>
                Create event
              </button>
            </div>
          </div>
        )}

        {step === 'bulk-dates' && (
          <div style={footerStyle}>
            <div style={{ fontSize: 13, color: attempted && !bulkStep1Valid ? '#c45656' : '#606266' }}>
              {(() => {
                if (!attempted || bulkStep1Valid) {
                  return selectedDates.length === 0
                    ? 'Pick at least one date to continue'
                    : <>Selected: <b>{selectedDates.length}</b> date{selectedDates.length !== 1 ? 's' : ''}</>;
                }
                const miss = [];
                if (selectedDates.length === 0) miss.push('dates');
                if (!prefix.trim()) miss.push('name pattern');
                if (!sharedLoc) miss.push('location');
                if (!sharedStart) miss.push('start time');
                if (!sharedEnd) miss.push('end time');
                return <>Missing: <b>{miss.join(', ')}</b></>;
              })()}
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button onClick={onClose} style={btnSecondary}>Cancel</button>
              <button onClick={tryGoToReview}
                style={canReview ? btnPrimary : btnPrimaryDisabled}>
                Review {selectedDates.length || ''} event{selectedDates.length !== 1 ? 's' : ''} <Icon name="ArrowRight" size={11} />
              </button>
            </div>
          </div>
        )}

        {step === 'bulk-review' && (
          <div style={footerStyle}>
            <div style={{ fontSize: 13, color: canConfirmBulk ? '#606266' : '#c47c5e' }}>
              {canConfirmBulk
                ? <>Will create <b>{rows.length}</b> event{rows.length !== 1 ? 's' : ''}</>
                : `${missingInReview} row${missingInReview !== 1 ? 's' : ''} need fixing — check empty cells`}
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button onClick={() => setStep('bulk-dates')} style={btnSecondary}><Icon name="ArrowLeft" size={11} /> Back</button>
              <button onClick={onClose} style={btnSecondary}>Cancel</button>
              <button onClick={confirmBulk} disabled={!canConfirmBulk}
                style={canConfirmBulk ? btnPrimary : btnPrimaryDisabled}>
                Create {rows.length} event{rows.length !== 1 ? 's' : ''}
              </button>
            </div>
          </div>
        )}
      </div>

      <style>{`
        @keyframes slideDown {
          from { opacity: 0; transform: translateY(-6px); }
          to { opacity: 1; transform: translateY(0); }
        }
      `}</style>
    </div>
  );
}

// ---------- Header variants ----------
function SingleOrDatesHeader({ title, onClose }) {
  return (
    <div style={headerStyle}>
      <div style={{ fontSize: 18, fontWeight: 600, color: '#303133', letterSpacing: '-0.005em' }}>{title}</div>
      <button onClick={onClose} style={closeBtn}><Icon name="Close" size={14} /></button>
    </div>
  );
}

function StepHeader({ step, total, title, subtitle, onClose }) {
  return (
    <div style={{ ...headerStyle, flexDirection: 'column', alignItems: 'stretch', gap: 8, padding: '16px 24px 14px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 11, fontWeight: 600, color: '#EAA034', textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 3 }}>
            Step {step} of {total}
          </div>
          <div style={{ fontSize: 18, fontWeight: 600, color: '#303133', letterSpacing: '-0.005em' }}>{title}</div>
          <div style={{ fontSize: 13, color: '#909399', marginTop: 2 }}>{subtitle}</div>
        </div>
        <button onClick={onClose} style={closeBtn}><Icon name="Close" size={14} /></button>
      </div>
      <div style={{ display: 'flex', gap: 4, marginTop: 4 }}>
        {Array.from({ length: total }).map((_, i) => (
          <div key={i} style={{
            flex: 1, height: 3, borderRadius: 2,
            background: i < step ? '#EAA034' : '#ebeef5',
            transition: 'background 200ms',
          }} />
        ))}
      </div>
    </div>
  );
}

const headerStyle = { display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '18px 24px 14px', borderBottom: '1px solid #ebeef5' };
const closeBtn = { background: 'transparent', border: 'none', cursor: 'pointer', fontSize: 22, color: '#909399', lineHeight: 1, fontFamily: 'inherit' };
const footerStyle = { display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 24px', borderTop: '1px solid #ebeef5', gap: 12 };
const panelStyle = { padding: 14, background: '#fff', border: '1px solid #ebeef5', borderRadius: 4, marginBottom: 14 };
const sectionLabel = { fontSize: 12, fontWeight: 700, color: '#606266', textTransform: 'uppercase', letterSpacing: 0.5 };
const btnSecondary = { background: '#fff', border: '1px solid #dcdfe6', color: '#606266', padding: '8px 16px', borderRadius: 4, fontSize: 14, cursor: 'pointer', fontFamily: 'inherit', fontWeight: 500 };
const btnPrimary = { background: '#409eff', border: '1px solid #409eff', color: '#fff', padding: '8px 16px', borderRadius: 4, fontSize: 14, cursor: 'pointer', fontFamily: 'inherit', fontWeight: 500 };
const btnPrimaryDisabled = { ...btnPrimary, background: '#a0cfff', border: '1px solid #a0cfff', cursor: 'not-allowed' };

Object.assign(window, { CreateEventsModal, LOCATIONS });
