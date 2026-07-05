// Signup with email/password is restricted to reputable mailbox providers to
// keep out disposable / throwaway addresses. OAuth logins bypass this (the
// provider has already verified the user). Academic domains are allowed so
// students and mentors can register with institution email.
export const TRUSTED_EMAIL_DOMAINS = new Set<string>([
  "gmail.com", "googlemail.com",
  "yahoo.com", "yahoo.in", "yahoo.co.in", "yahoo.co.uk", "ymail.com", "rocketmail.com",
  "outlook.com", "outlook.in", "hotmail.com", "hotmail.co.uk", "live.com", "msn.com",
  "icloud.com", "me.com", "mac.com",
  "proton.me", "protonmail.com", "pm.me",
  "aol.com", "zoho.com", "zohomail.com", "zoho.in",
  "gmx.com", "gmx.net", "mail.com", "fastmail.com", "yandex.com", "hey.com", "tutanota.com",
]);

// Academic suffixes are trusted too (institution mailboxes are not disposable).
const ACADEMIC_SUFFIXES = [".edu", ".ac.in", ".edu.in", ".ac.uk", ".edu.au"];

export function isTrustedEmailDomain(email: string): boolean {
  const at = email.lastIndexOf("@");
  if (at < 0) return false;
  const domain = email.slice(at + 1).toLowerCase().trim();
  if (TRUSTED_EMAIL_DOMAINS.has(domain)) return true;
  return ACADEMIC_SUFFIXES.some((s) => domain.endsWith(s));
}

export const TRUSTED_DOMAINS_HINT =
  "Use Gmail, Yahoo, Outlook, iCloud, Proton, or a school email.";
