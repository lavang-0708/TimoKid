import { useState, type FormEvent } from 'react';
import { http } from '../client';
import { Card, ErrorBox, Spinner, errorText, useLoad } from '../common';
import { deleteUnopenedMessage, listMessages, sendMessage } from '../lib/data';
import { MESSAGE_MAX, MESSAGE_STATUS_VI, formatVnDateTime, messageStatus, validateMessage } from '../lib/logic';

export function MessagesScreen({ childId, childName }: { childId: string; childName: string }) {
  const [body, setBody] = useState('');
  const [xu, setXu] = useState('');
  const [gem, setGem] = useState('');
  const [item, setItem] = useState('');
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);
  const q = useLoad(() => listMessages(http, childId), [childId]);
  const len = [...body].length;

  async function send(e: FormEvent) {
    e.preventDefault();
    const v = validateMessage({ body, giftXu: xu, giftGem: gem, giftItemId: item });
    if (!v.ok) {
      setNotice({ ok: false, text: v.errors.join(' ') });
      return;
    }
    setBusy(true);
    setNotice(null);
    try {
      await sendMessage(http, childId, v.value);
      setBody('');
      setXu('');
      setGem('');
      setItem('');
      setNotice({ ok: true, text: `Đã gửi thư cho ${childName}. Bé sẽ thấy thư sau lần đồng bộ tiếp theo.` });
      q.reload();
    } catch (err) {
      setNotice({ ok: false, text: errorText(err) });
    } finally {
      setBusy(false);
    }
  }

  async function remove(id: string) {
    if (!window.confirm('Xóa thư này? Bé chưa mở nên sẽ không thấy thư.')) return;
    try {
      const done = await deleteUnopenedMessage(http, id);
      setNotice(done ? { ok: true, text: 'Đã xóa thư.' } : { ok: false, text: 'Bé vừa mở thư nên không xóa được nữa.' });
    } catch (err) {
      setNotice({ ok: false, text: errorText(err) });
    }
    q.reload();
  }

  return (
    <>
      <h2>Thư và quà cho {childName}</h2>
      <form className="card pink" onSubmit={send}>
        <label htmlFor="body">Lời nhắn</label>
        <textarea id="body" rows={4} value={body} onChange={(e) => setBody(e.target.value)} placeholder="Viết vài lời cho bé…" />
        <div className={`counter ${len > MESSAGE_MAX ? 'over' : ''}`}>{len}/{MESSAGE_MAX}</div>
        <div className="grid">
          <div>
            <label htmlFor="xu">Xu tặng (0-1000)</label>
            <input id="xu" inputMode="numeric" value={xu} onChange={(e) => setXu(e.target.value)} placeholder="0" />
          </div>
          <div>
            <label htmlFor="gem">Kim cương tặng (0-100)</label>
            <input id="gem" inputMode="numeric" value={gem} onChange={(e) => setGem(e.target.value)} placeholder="0" />
          </div>
        </div>
        <label htmlFor="item">Mã món đồ tặng (không bắt buộc)</label>
        <input id="item" value={item} onChange={(e) => setItem(e.target.value)} maxLength={60} />
        {notice && <div className={`banner ${notice.ok ? 'ok' : 'err'}`}>{notice.text}</div>}
        <div style={{ marginTop: 12 }}>
          <button type="submit" disabled={busy}>{busy ? 'Đang gửi…' : 'Gửi thư'}</button>
        </div>
      </form>

      <Card title="Thư đã gửi">
        {q.error != null && <ErrorBox error={q.error} onRetry={q.reload} />}
        {q.loading && !q.data && <Spinner />}
        {q.data && q.data.length === 0 && <p className="muted">Chưa gửi thư nào.</p>}
        {q.data?.map((m) => {
          const st = messageStatus(m);
          const gifts = [m.gift_xu > 0 && `${m.gift_xu} xu`, m.gift_gem > 0 && `${m.gift_gem} kim cương`, m.gift_item_id && `món ${m.gift_item_id}`].filter(Boolean);
          return (
            <div className="msg" key={m.id}>
              <div className="row" style={{ justifyContent: 'space-between' }}>
                <span className="muted">{formatVnDateTime(m.created_at)}</span>
                <span className={`pill ${st === 'unopened' ? 'warn' : 'mint'}`}>{MESSAGE_STATUS_VI[st]}</span>
              </div>
              <p>{m.body}</p>
              {gifts.length > 0 && <div className="muted">Quà: {gifts.join(', ')}</div>}
              {st === 'unopened' && (
                <button className="danger" style={{ marginTop: 6 }} onClick={() => remove(m.id)}>Xóa thư</button>
              )}
            </div>
          );
        })}
      </Card>
    </>
  );
}
