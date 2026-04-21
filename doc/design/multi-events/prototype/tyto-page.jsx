// Tyto mock — matches the real Vue/Element Plus styling
// Header: #EFCD76 gold. Accent: #824533 rust. Cards: #f2f2f2 bg.

const T = {
  headerBg: '#EFCD76',
  iconStroke: '#fff',
  iconFill: '#EFCD76',
  accent: '#824533',
  accentHover: '#6e3a2b',
  navActive: '#EAA034',
  text: '#2c3e50',
  textMuted: '#606266',
  textSoft: '#909399',
  cardBg: '#f2f2f2',
  cardBorder: '#e4e7ed',
  pageBg: 'rgb(239, 239, 239)',
  surface: '#ffffff',
  line: '#dcdfe6',
  lineSoft: '#ebeef5',
  warn: '#e6a23c',
  warnBg: '#fdf6ec',
  danger: '#f56c6c',
  success: '#67c23a',
};

// Element Plus-ish button
function ElButton({ type, color, children, onClick, size, style, icon, disabled }) {
  const bg = disabled ? '#f5f7fa' : (color || (type === 'primary' ? '#409eff' : type === 'danger' ? T.danger : '#fff'));
  const fg = disabled ? '#c0c4cc' : (color || type ? '#fff' : T.text);
  const border = color || type ? 'transparent' : T.line;
  const pad = size === 'small' ? '6px 12px' : '8px 15px';
  const fs = size === 'small' ? 12 : 14;
  return (
    <button onClick={disabled ? undefined : onClick} disabled={disabled} style={{
      background: bg, color: fg,
      border: `1px solid ${border}`,
      padding: pad, borderRadius: 4, fontSize: fs, fontWeight: 500,
      cursor: disabled ? 'not-allowed' : 'pointer',
      display: 'inline-flex', alignItems: 'center', gap: 6,
      transition: 'all 120ms ease',
      ...style,
    }}
    onMouseEnter={e => { if (!disabled && color) e.currentTarget.style.filter = 'brightness(1.1)'; }}
    onMouseLeave={e => { e.currentTarget.style.filter = 'none'; }}
    >
      {icon && <span style={{ fontSize: fs }}>{icon}</span>}
      {children}
    </button>
  );
}

function TytoHeader() {
  return (
    <div style={{
      background: T.headerBg, height: 80,
      display: 'flex', alignItems: 'center', padding: '0 24px',
      position: 'relative',
      userSelect: 'none',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
        <div style={{
          width: 50, height: 50, borderRadius: '50%',
          background: T.headerBg, border: `3px solid #fff`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          margin: 15, marginLeft: 0,
          boxShadow: '0 2px 4px rgba(0,0,0,0.08)',
        }}>
          {/* Owl icon placeholder */}
          <span style={{ fontSize: 24 }}>🦉</span>
        </div>
        <span style={{
          fontSize: '2.5rem', fontWeight: 900, fontStyle: 'italic',
          lineHeight: '80px', color: T.headerBg,
          WebkitTextFillColor: T.headerBg,
          WebkitTextStroke: '3px #fff',
          letterSpacing: '-0.02em',
        }}>TYTO</span>
      </div>
      <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 16 }}>
        <span style={{ color: '#fff', fontWeight: 900, lineHeight: '80px', fontSize: 14 }}>
          Cherry Salmon — Instructor
        </span>
        <div style={{
          width: 40, height: 40, borderRadius: '50%', background: '#fff',
          margin: 20, marginLeft: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontWeight: 700, color: T.accent, fontSize: 14,
          boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        }}>CS</div>
      </div>
    </div>
  );
}

function CourseTabs() {
  return (
    <ul style={{
      listStyle: 'none', margin: 0, padding: 0,
      display: 'flex', flexDirection: 'column', width: 180,
    }}>
      {[
        { label: 'Attendance Events', active: true },
        { label: 'Locations', active: false },
        { label: 'People', active: false },
      ].map((t, i) => (
        <li key={i} style={{ margin: '5px 0' }}>
          <a style={{
            display: 'block', textAlign: 'center', padding: '10px',
            fontSize: '1rem', fontWeight: 800, borderRadius: 5,
            color: t.active ? T.navActive : '#333',
            textDecoration: 'none', cursor: 'pointer',
            background: 'transparent',
          }}>{t.label}</a>
        </li>
      ))}
    </ul>
  );
}

// Attendance event card — matches .event-item (el-card, 20% wide, #f2f2f2 bg)
function EventCard({ name, location, date, dimmed, onClick }) {
  return (
    <div onClick={onClick} style={{
      background: T.cardBg,
      borderRadius: 4,
      border: `1px solid ${T.cardBorder}`,
      padding: '16px 18px',
      minWidth: 200,
      margin: 10,
      flex: '0 0 auto', width: 200,
      cursor: 'pointer',
      boxShadow: '0 2px 4px rgba(0,0,0,0.06)',
      transition: 'box-shadow 180ms ease',
      opacity: dimmed ? 0.5 : 1,
    }}
    onMouseEnter={e => { e.currentTarget.style.boxShadow = '0 6px 16px rgba(0,0,0,0.12)'; }}
    onMouseLeave={e => { e.currentTarget.style.boxShadow = '0 2px 4px rgba(0,0,0,0.06)'; }}
    >
      <h3 style={{ margin: '0 0 8px', fontSize: 16, fontWeight: 700, color: T.text }}>{name}</h3>
      <p style={{ margin: '4px 0', fontSize: 13, color: T.textMuted }}>Location: {location}</p>
      <p style={{ margin: '4px 0 12px', fontSize: 12, color: T.textSoft }}>{date}</p>
      <div style={{ display: 'flex', gap: 10, fontSize: 16, color: T.textMuted }}>
        <span title="Map">📍</span>
        <span title="Attendance">👤</span>
        <span title="Edit">✏️</span>
        <span title="Delete">🗑️</span>
      </div>
    </div>
  );
}

// "Create Event" card — matches existing single create
function CreateEventCard({ onClick, label, sublabel, variant = 'single' }) {
  const isBulk = variant === 'bulk';
  return (
    <div onClick={onClick} style={{
      background: isBulk ? '#fff' : T.cardBg,
      borderRadius: 4,
      border: isBulk ? `2px dashed ${T.accent}` : `1px solid ${T.cardBorder}`,
      padding: '16px 18px',
      width: 200,
      margin: 10,
      flex: '0 0 auto',
      cursor: 'pointer',
      boxShadow: '0 2px 4px rgba(0,0,0,0.06)',
      transition: 'all 180ms ease',
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      minHeight: 148,
      textAlign: 'center',
    }}
    onMouseEnter={e => {
      e.currentTarget.style.boxShadow = '0 6px 16px rgba(0,0,0,0.14)';
      e.currentTarget.style.transform = 'translateY(-1px)';
    }}
    onMouseLeave={e => {
      e.currentTarget.style.boxShadow = '0 2px 4px rgba(0,0,0,0.06)';
      e.currentTarget.style.transform = 'none';
    }}
    >
      <div style={{ fontSize: 28, color: isBulk ? T.accent : T.text, lineHeight: 1, marginBottom: 8 }}>
        {isBulk ? '⊞' : '+'}
      </div>
      <h3 style={{ margin: '0 0 4px', fontSize: 16, fontWeight: 700, color: T.text }}>{label}</h3>
      {sublabel && <div style={{ fontSize: 12, color: T.textSoft }}>{sublabel}</div>}
    </div>
  );
}

// Realistic course events for the mock
const EXISTING_EVENTS = [
  { name: 'Week 01 — Lecture', location: 'DeBartolo 101', date: 'Aug 26, 11:00–12:15' },
  { name: 'Week 02 — Lecture', location: 'DeBartolo 101', date: 'Sep 02, 11:00–12:15' },
  { name: 'Week 03 — Lecture', location: 'DeBartolo 101', date: 'Sep 09, 11:00–12:15' },
  { name: 'Week 04 — Lecture', location: 'DeBartolo 101', date: 'Sep 16, 11:00–12:15' },
  { name: 'Week 05 — Lecture', location: 'DeBartolo 101', date: 'Sep 23, 11:00–12:15' },
  { name: 'Week 06 — Lecture', location: 'DeBartolo 101', date: 'Sep 30, 11:00–12:15' },
  { name: 'Week 07 — Lecture', location: 'DeBartolo 101', date: 'Oct 07, 11:00–12:15' },
];

function TytoPage({ onOpenBulk, onOpenSingle, entryPointStyle = 'two-cards', tweakedEvents = [] }) {
  const allEvents = [...EXISTING_EVENTS, ...tweakedEvents];
  return (
    <div style={{ background: T.pageBg, minHeight: '100%', color: T.text }}>
      <TytoHeader />
      <div style={{
        maxWidth: 1680, margin: 'auto', width: '95%',
        padding: '15px 30px',
      }}>
        <div style={{
          fontSize: '3em', fontWeight: 700,
          padding: '10px 10px 20px 10px',
          textAlign: 'left', letterSpacing: '-0.01em',
        }}>Neural Networks · Fall 2025</div>

        <div style={{ display: 'flex', gap: 20, flexWrap: 'wrap' }}>
          {/* Left sidebar tabs */}
          <div style={{ flex: '0 0 180px' }}>
            <CourseTabs />
          </div>

          {/* Main content */}
          <div style={{ flex: '1 1 600px', textAlign: 'left' }}>
            <div style={{
              fontSize: '1.5rem', textAlign: 'left',
              padding: '0px 20px', width: '100%',
              fontWeight: 500,
            }}>Attendance Events</div>

            <div style={{ width: '100%', margin: '20px 10px 10px 10px', textAlign: 'left' }}>
              <ElButton color={T.accent}>Download Record</ElButton>
            </div>

            <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'flex-start' }}>
              <CreateEventCard onClick={onOpenBulk} label="Create Event" sublabel="One or many" variant="bulk" />
              {allEvents.map((e, i) => (
                <EventCard key={i} {...e} dimmed={false} />
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { TytoPage, EXISTING_EVENTS, T });
