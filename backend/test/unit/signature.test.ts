import { describe, expect, it } from "vitest";
import { sign, verify } from "../../src/modules/payments/signature.js";

const secret = "whsec_test";
const body = Buffer.from('{"id":"evt_1","type":"payment_intent.succeeded"}');

describe("webhook signatures", () => {
  it("accepts a correctly signed, fresh payload", () => {
    expect(verify(secret, body, sign(secret, body))).toBe(true);
  });

  it("rejects a tampered body", () => {
    const header = sign(secret, body);
    expect(verify(secret, Buffer.from(body.toString().replace("succeeded", "failed")), header)).toBe(false);
  });

  it("rejects the wrong secret", () => {
    expect(verify(secret, body, sign("whsec_other", body))).toBe(false);
  });

  it("rejects replays outside the tolerance window", () => {
    const tenMinutesAgo = Math.floor(Date.now() / 1000) - 600;
    expect(verify(secret, body, sign(secret, body, tenMinutesAgo))).toBe(false);
  });

  it("rejects malformed headers", () => {
    expect(verify(secret, body, undefined)).toBe(false);
    expect(verify(secret, body, "garbage")).toBe(false);
    expect(verify(secret, body, "t=1,v1=zz")).toBe(false);
  });
});
