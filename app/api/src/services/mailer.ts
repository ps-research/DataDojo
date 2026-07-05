import nodemailer from "nodemailer";

// SMTP is configured via env (Gmail app-password is the simplest free path).
// When unconfigured, we fall back to logging the code server-side so the flow
// is still exercisable in dev - never returned to the client.
const host = process.env.SMTP_HOST ?? "smtp.gmail.com";
const port = parseInt(process.env.SMTP_PORT ?? "587", 10);
const user = process.env.SMTP_USER ?? "";
const pass = process.env.SMTP_PASS ?? "";
const from = process.env.MAIL_FROM ?? `DataDojo <${user}>`;

export const mailerConfigured = Boolean(user && pass);

let transport: nodemailer.Transporter | null = null;
function getTransport(): nodemailer.Transporter {
  if (!transport) {
    transport = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
    });
  }
  return transport;
}

function otpHtml(code: string, name: string): string {
  return `<!doctype html><html><body style="margin:0;background:#f4f4f5;font-family:-apple-system,Segoe UI,Roboto,sans-serif">
  <div style="max-width:440px;margin:32px auto;background:#fff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
    <div style="padding:28px 32px 8px">
      <div style="display:inline-block;width:34px;height:34px;border-radius:9px;background:#3b6ef2"></div>
      <h1 style="margin:16px 0 4px;font-size:19px;color:#18181b">Confirm your email</h1>
      <p style="margin:0;color:#71717a;font-size:14px">Hi ${name || "there"}, enter this code in DataDojo to finish signing up.</p>
    </div>
    <div style="padding:20px 32px 8px">
      <div style="font-size:34px;letter-spacing:10px;font-weight:700;color:#18181b;text-align:center;padding:16px;background:#f4f4f5;border-radius:10px">${code}</div>
      <p style="margin:16px 0 0;color:#a1a1aa;font-size:12px;text-align:center">This code expires in 10 minutes. If you did not request it, ignore this email.</p>
    </div>
    <div style="padding:16px 32px 28px;color:#a1a1aa;font-size:12px">- DataDojo</div>
  </div></body></html>`;
}

export async function sendOtpEmail(to: string, code: string, name: string): Promise<void> {
  if (!mailerConfigured) {
    console.log(`[mailer] (unconfigured) OTP for ${to}: ${code}`);
    return;
  }
  await getTransport().sendMail({
    from,
    to,
    subject: `${code} is your DataDojo verification code`,
    text: `Your DataDojo verification code is ${code}. It expires in 10 minutes.`,
    html: otpHtml(code, name),
  });
}
