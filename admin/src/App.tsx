import { useCallback, useEffect, useState } from 'react';
import { http } from './client';
import { ErrorBox, Spinner, useLoad } from './common';
import { ensureFamily, listChildren, type Child } from './lib/data';
import type { AuthUser } from './lib/http';
import { cleanUrl, parseResetParams, type ResetParams } from './lib/authForm';
import { AuthScreen } from './screens/AuthScreen';
import { ResetPasswordScreen } from './screens/ResetPasswordScreen';
import { ChildPicker, SyncLine } from './screens/ChildPicker';
import { CustomQuestionsScreen } from './screens/CustomQuestionsScreen';
import { FormsScreen } from './screens/FormsScreen';
import { MessagesScreen } from './screens/MessagesScreen';
import { SettingsScreen } from './screens/SettingsScreen';
import { StatsScreen } from './screens/StatsScreen';

type Tab = 'stats' | 'forms' | 'custom' | 'mail' | 'settings';
const TABS: { id: Tab; label: string }[] = [
  { id: 'stats', label: 'Thống kê' },
  { id: 'forms', label: 'Dạng bài' },
  { id: 'custom', label: 'Đề tự soạn' },
  { id: 'mail', label: 'Thư và quà' },
  { id: 'settings', label: 'Cài đặt' },
];
const CHILD_KEY = 'timokid.admin.child';

export function App() {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [booting, setBooting] = useState(true);
  const [bootError, setBootError] = useState<unknown>(null);
  const [waking, setWaking] = useState(false);
  const [expired, setExpired] = useState(false);
  // Liên kết trong email đặt lại mật khẩu: /TimoKid/?token=... (hoặc ?error=...).
  const [reset, setReset] = useState<ResetParams>(() => parseResetParams(window.location.search));

  function finishReset() {
    window.history.replaceState(null, '', cleanUrl(window.location.href));
    setReset(null);
  }

  useEffect(() => http.subscribeWaking(setWaking), []);
  useEffect(() => {
    http.onAuthLost = () => {
      setUser(null);
      setExpired(true);
    };
    return () => {
      http.onAuthLost = null;
    };
  }, []);

  const boot = useCallback(() => {
    setBooting(true);
    setBootError(null);
    http
      .restore()
      .then((u) => setUser(u))
      .catch((e) => setBootError(e))
      .finally(() => setBooting(false));
  }, []);
  useEffect(boot, [boot]);

  const wakingBanner = waking && <div className="banner warn">Đang đánh thức máy chủ… vài giây nữa là xong.</div>;

  if (reset) return <ResetPasswordScreen params={reset} onDone={finishReset} />;
  if (booting) return <>{wakingBanner}<Spinner text="Đang kiểm tra đăng nhập…" /></>;
  if (bootError != null) return <ErrorBox error={bootError} onRetry={boot} />;
  if (!user) {
    return (
      <>
        {wakingBanner}
        {expired && <div className="banner warn">Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.</div>}
        <AuthScreen onSignedIn={(u) => { setExpired(false); setUser(u); }} />
      </>
    );
  }
  return <Signed user={user} wakingBanner={wakingBanner} onSignOut={async () => { await http.signOut(); setUser(null); }} />;
}

function Signed({ user, wakingBanner, onSignOut }: { user: AuthUser; wakingBanner: React.ReactNode; onSignOut: () => void }) {
  const [tab, setTab] = useState<Tab>('stats');
  const [childId, setChildId] = useState<string | null>(() => localStorage.getItem(CHILD_KEY));
  const q = useLoad(async () => {
    await ensureFamily(http);
    return listChildren(http);
  }, [user.id]);
  const kids: Child[] | null = q.data;
  const child = kids?.find((c) => c.id === childId) ?? (kids?.length === 1 ? kids[0] : null);

  function pick(c: Child | null) {
    setChildId(c?.id ?? null);
    if (c) localStorage.setItem(CHILD_KEY, c.id);
    else localStorage.removeItem(CHILD_KEY);
    setTab('stats');
  }

  return (
    <>
      <div className="top">
        <span className="brand">TimoKid<small>Phụ huynh</small></span>
        <button className="ghost" onClick={onSignOut}>Đăng xuất</button>
      </div>
      <div className="muted account" title="Tài khoản đang đăng nhập">{user.email}</div>
      {wakingBanner}
      {child ? (
        <>
          <div className="card lav row" style={{ justifyContent: 'space-between' }}>
            <div>
              <b>{child.name}</b> <span className="pill">Lớp {child.grade}</span>
              <div><SyncLine at={child.last_synced_at} /></div>
            </div>
            <div className="row">
              <button className="chip" onClick={q.reload} title="Tải lại hồ sơ">Làm mới</button>
              {kids && kids.length > 1 && <button className="chip" onClick={() => pick(null)}>Đổi bé</button>}
            </div>
          </div>
          {tab === 'stats' && <StatsScreen childId={child.id} />}
          {tab === 'forms' && <FormsScreen childId={child.id} />}
          {tab === 'custom' && <CustomQuestionsScreen kids={kids ?? []} />}
          {tab === 'mail' && <MessagesScreen childId={child.id} childName={child.name} />}
          {tab === 'settings' && <SettingsScreen child={child} kids={kids ?? []} email={user.email} onChildrenChanged={q.reload} />}
          <nav className="tabs">
            {TABS.map((t) => (
              <button key={t.id} className={tab === t.id ? 'on' : ''} onClick={() => setTab(t.id)}>{t.label}</button>
            ))}
          </nav>
        </>
      ) : (
        <ChildPicker children={kids} loading={q.loading} error={q.error} onRetry={q.reload} onPick={pick} />
      )}
    </>
  );
}
