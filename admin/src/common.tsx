import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { ApiError } from './lib/http';

export function errorText(e: unknown): string {
  if (e instanceof ApiError) {
    if (e.kind === 'network') return 'Không kết nối được mạng. Hãy kiểm tra kết nối rồi thử lại.';
    if (e.kind === 'auth') return 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.';
    if (e.kind === 'server') return 'Máy chủ đang bận hoặc vừa thức dậy. Hãy thử lại sau ít giây.';
    return `Có lỗi: ${e.message}`;
  }
  return 'Có lỗi không rõ. Hãy thử lại.';
}

export function Spinner({ text = 'Đang tải…' }: { text?: string }) {
  return <div className="spinner">{text}</div>;
}

export function ErrorBox({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  return (
    <div className="banner err">
      {errorText(error)}{' '}
      {onRetry && (
        <button className="link" onClick={onRetry}>
          Thử lại
        </button>
      )}
    </div>
  );
}

export interface Loaded<T> {
  data: T | null;
  error: unknown;
  loading: boolean;
  reload: () => void;
  setData: (d: T) => void;
}

/** Tải dữ liệu khi `deps` đổi; bỏ kết quả của lần gọi cũ. */
export function useLoad<T>(fn: () => Promise<T>, deps: unknown[]): Loaded<T> {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [loading, setLoading] = useState(true);
  const [tick, setTick] = useState(0);
  const fnRef = useRef(fn);
  fnRef.current = fn;
  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError(null);
    fnRef
      .current()
      .then((d) => alive && setData(d))
      .catch((e) => alive && setError(e))
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick]);
  const reload = useCallback(() => setTick((t) => t + 1), []);
  return { data, error, loading, reload, setData };
}

export function Card({ title, children, tone }: { title?: string; children: ReactNode; tone?: 'mint' | 'lav' | 'pink' }) {
  return (
    <section className={`card ${tone ?? ''}`}>
      {title && <h3 style={{ marginTop: 0 }}>{title}</h3>}
      {children}
    </section>
  );
}

export function RangePicker({ value, onChange, options = [7, 30] }: { value: number; onChange: (n: number) => void; options?: number[] }) {
  return (
    <div className="row">
      {options.map((n) => (
        <button key={n} className={`chip ${value === n ? 'on' : ''}`} onClick={() => onChange(n)}>
          {n} ngày
        </button>
      ))}
    </div>
  );
}
