import type { Child } from '../lib/data';
import { formatVnDateTime, relativeVi } from '../lib/logic';
import { Card, ErrorBox, Spinner } from '../common';

export function SyncLine({ at }: { at: string | null }) {
  return (
    <span className="muted">
      {at ? `Đồng bộ lần cuối: ${formatVnDateTime(at)} (${relativeVi(at)})` : 'Đồng bộ lần cuối: chưa có'}
    </span>
  );
}

export function ChildPicker(props: {
  children: Child[] | null;
  loading: boolean;
  error: unknown;
  onRetry: () => void;
  onPick: (c: Child) => void;
}) {
  const { children, loading, error, onRetry, onPick } = props;
  if (loading && !children) return <Spinner />;
  if (error && !children) return <ErrorBox error={error} onRetry={onRetry} />;
  if (!children || children.length === 0) {
    return (
      <Card title="Chưa có hồ sơ bé" tone="lav">
        <p>
          Hồ sơ của bé sẽ xuất hiện sau khi app trên điện thoại của bé đăng nhập bằng cùng tài khoản này và đồng bộ lần đầu.
          Trang này chưa tạo được hồ sơ bé.
        </p>
        <button onClick={onRetry}>Tải lại</button>
      </Card>
    );
  }
  return (
    <>
      <h2>Chọn bé</h2>
      {children.map((c) => (
        <button key={c.id} className="child-btn" onClick={() => onPick(c)}>
          <b style={{ fontSize: '1.15rem' }}>{c.name}</b> <span className="pill">Lớp {c.grade}</span>
          <div>
            <SyncLine at={c.last_synced_at} />
          </div>
        </button>
      ))}
    </>
  );
}
