import { assertEquals } from "jsr:@std/assert@1";
import { MAX_URL_LAENGE, pruefeUrl, urlErlaubt } from "./url_pruefung.ts";

Deno.test("öffentliche Websites sind erlaubt", () => {
  assertEquals(urlErlaubt("https://www.beispiel-restaurant.ch"), true);
  assertEquals(urlErlaubt("http://beispiel.ch/kontakt"), true);
  assertEquals(urlErlaubt("www.beispiel.ch"), true); // nackte Domain aus dem Betrieb
  assertEquals(pruefeUrl("beispiel.ch"), "https://beispiel.ch/");
  assertEquals(urlErlaubt("https://8.8.8.8/"), true);
});

Deno.test("fremde Schemas werden abgewiesen", () => {
  assertEquals(urlErlaubt("ftp://beispiel.ch"), false);
  assertEquals(urlErlaubt("file:///etc/passwd"), false);
  assertEquals(urlErlaubt("javascript:alert(1)"), false);
  assertEquals(urlErlaubt("data:text/html,x"), false);
});

Deno.test("Loopback und localhost werden abgewiesen", () => {
  assertEquals(urlErlaubt("http://localhost"), false);
  assertEquals(urlErlaubt("http://localhost:54321/rest/v1/"), false);
  assertEquals(urlErlaubt("http://foo.localhost"), false);
  assertEquals(urlErlaubt("http://127.0.0.1"), false);
  assertEquals(urlErlaubt("http://127.1.2.3:8080/x"), false);
  assertEquals(urlErlaubt("http://[::1]/"), false);
  assertEquals(urlErlaubt("http://0.0.0.0/"), false);
  // Umgehungs-Schreibweisen, die der URL-Parser zu 127.0.0.1 normalisiert
  assertEquals(urlErlaubt("http://2130706433/"), false);
  assertEquals(urlErlaubt("http://0x7f.1/"), false);
  assertEquals(urlErlaubt("http://[::ffff:127.0.0.1]/"), false);
});

Deno.test("private Netze und Metadaten werden abgewiesen", () => {
  assertEquals(urlErlaubt("http://10.0.0.5"), false);
  assertEquals(urlErlaubt("http://192.168.1.1/admin"), false);
  assertEquals(urlErlaubt("http://172.16.0.1"), false);
  assertEquals(urlErlaubt("http://172.31.255.255"), false);
  assertEquals(urlErlaubt("http://172.32.0.1"), true); // ausserhalb 172.16/12
  assertEquals(urlErlaubt("http://169.254.169.254/latest/meta-data"), false);
  assertEquals(urlErlaubt("http://[fd00::1]/"), false);
  assertEquals(urlErlaubt("http://[fe80::1]/"), false);
  assertEquals(urlErlaubt("http://metadata.google.internal/"), false);
});

Deno.test("Länge, Typ und Zugangsdaten in der URL", () => {
  assertEquals(urlErlaubt(""), false);
  assertEquals(urlErlaubt("   "), false);
  assertEquals(urlErlaubt(null), false);
  assertEquals(urlErlaubt(42), false);
  const lang = "https://beispiel.ch/" + "a".repeat(MAX_URL_LAENGE);
  assertEquals(urlErlaubt(lang), false);
  assertEquals(urlErlaubt("https://user:pw@beispiel.ch/"), false);
});
