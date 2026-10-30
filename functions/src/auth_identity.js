export const INTERNAL_AUTH_DOMAIN = 'auth.rokterbadhon.internal';

const BENGALI_DIGITS = '০১২৩৪৫৬৭৮৯';
const LATIN_DIGITS = '0123456789';

export function normalizePhone(value) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error('Phone number is required.');
  }
  let phone = value.trim();
  for (let index = 0; index < BENGALI_DIGITS.length; index += 1) {
    phone = phone.replaceAll(BENGALI_DIGITS[index], LATIN_DIGITS[index]);
  }
  phone = phone.replace(/[\s().-]/g, '');
  if (phone.startsWith('+')) phone = phone.slice(1);
  if (phone.startsWith('00880')) phone = phone.slice(2);
  if (phone.startsWith('880')) phone = `0${phone.slice(3)}`;
  if (!/^01[0-9]{9}$/.test(phone)) {
    throw new Error('Phone number must be a valid Bangladesh number.');
  }
  return phone;
}

export function internalAuthEmailForPhone(phone) {
  return `p${normalizePhone(phone)}@${INTERNAL_AUTH_DOMAIN}`;
}
