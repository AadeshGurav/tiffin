import sys
from xml.sax.saxutils import escape as esc
import os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "diagrams") + os.sep
PAPER, PAPER2, INK, MUTED, SOFT, RULE = "#f5f5f5", "#ececec", "#2d3142", "#4f5d75", "#5a6580", "#bfc0c0"
ACC, ACCT, LINK = "#bf4520", "#f5e3de", "#2e5aa8"
SANS = "Geist, 'Helvetica Neue', Arial, sans-serif"
MONO = "'Geist Mono', ui-monospace, Menlo, monospace"
SERIF = "'Instrument Serif', Georgia, serif"

def route(pts, r=8):
    d = f"M{pts[0][0]},{pts[0][1]}"
    for i in range(1, len(pts) - 1):
        (x0, y0), (x1, y1), (x2, y2) = pts[i-1], pts[i], pts[i+1]
        def toward(a, b, n):
            dx, dy = b[0]-a[0], b[1]-a[1]
            l = max(abs(dx), abs(dy)); return (a[0]+dx/l*n, a[1]+dy/l*n)
        p1 = toward((x1, y1), (x0, y0), r); p2 = toward((x1, y1), (x2, y2), r)
        d += f" L{p1[0]:g},{p1[1]:g} Q{x1},{y1} {p2[0]:g},{p2[1]:g}"
    return d + f" L{pts[-1][0]},{pts[-1][1]}"

class Svg:
    def __init__(s, slug, w, h, eyebrow, title, desc):
        s.slug, s.w, s.h, s.b, s.top = slug, w, h, [], []
        s.head = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img" '
                  f'aria-labelledby="{slug}-title {slug}-desc" font-family="{SANS}">\n<title id="{slug}-title">{esc(title)}</title>\n'
                  f'<desc id="{slug}-desc">{esc(desc)}</desc>\n<defs>'
                  + "".join(f'<marker id="{slug}-{n}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" fill="{c}"/></marker>'
                            for n, c in (("a", MUTED), ("c", ACC)))
                  + '</defs>\n'
                  f'<rect width="{w}" height="{h}" fill="{PAPER}"/>\n'
                  f'<text x="40" y="40" font-family="{MONO}" font-size="11" letter-spacing="1.6" fill="{ACC}">{esc(eyebrow.upper())}</text>\n'
                  f'<text x="40" y="76" font-family="{SERIF}" font-size="30" fill="{INK}">{esc(title)}</text>\n')
    def arrow(s, pts, accent=False, dashed=False, both=False):
        c = "c" if accent else "a"
        st = ACC if accent else MUTED
        s.b.append(f'<path d="{route(pts)}" fill="none" stroke="{st}" stroke-width="1.4"'
                   + (' stroke-dasharray="5,4"' if dashed else '') + f' marker-end="url(#{s.slug}-{c})"/>')
    def label(s, x, y, t, anchor="middle"):
        tw = len(t) * 6.2 + 12
        rx = x - tw/2 if anchor == "middle" else x - 6
        s.top.append(f'<rect x="{rx:g}" y="{y-11}" width="{tw:g}" height="15" fill="{PAPER}"/>'
                     f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{MONO}" font-size="9.5" letter-spacing=".8" fill="{SOFT}">{esc(t)}</text>')
    def node(s, x, y, w, h, name, subs=(), kind="n", top=False):
        fill, stroke, dash = {"n": ("#ffffff", INK, ""), "f": (ACCT, ACC, ""), "s": (PAPER2, MUTED, ""), "x": (PAPER, SOFT, ' stroke-dasharray="5,4"')}[kind]
        out = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{PAPER}"/>',
               f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{fill}" stroke="{stroke}" stroke-width="1.2"{dash}/>']
        if isinstance(subs, str): subs = (subs,)
        n = len(subs); cx = x + w/2
        ty = y + h/2 - (n*7 if n else 0) + 5
        out.append(f'<text x="{cx:g}" y="{ty:g}" text-anchor="middle" font-size="13.5" font-weight="600" fill="{INK}">{esc(name)}</text>')
        for i, t in enumerate(subs):
            out.append(f'<text x="{cx:g}" y="{ty+16+i*14:g}" text-anchor="middle" font-family="{MONO}" font-size="10" fill="{MUTED}">{esc(t)}</text>')
        s.top.append("\n".join(out)) if top else s.b.append("\n".join(out))
    def note(s, x, y, lines, size=16, anchor="start"):
        s.top.append("".join(f'<text x="{x}" y="{y+i*size*1.3:g}" text-anchor="{anchor}" font-family="{SERIF}" font-style="italic" font-size="{size}" fill="{MUTED}">{esc(t)}</text>' for i, t in enumerate(lines)))
    def text(s, x, y, t, color=SOFT):
        s.top.append(f'<text x="{x}" y="{y}" font-family="{MONO}" font-size="10.5" letter-spacing="1.4" fill="{color}">{esc(t.upper())}</text>')
    def pulse(s, pts, a, b, cycle, color=ACC):
        path = route(pts); kt = f"0;{a};{b};1"
        s.top.append(f'<circle r="4.5" fill="{color}" opacity="0"><animateMotion dur="{cycle}s" repeatCount="indefinite" path="{path}" '
                     f'calcMode="linear" keyPoints="0;0;1;1" keyTimes="{kt}"/>'
                     f'<animate attributeName="opacity" dur="{cycle}s" repeatCount="indefinite" calcMode="discrete" keyTimes="0;{a};{b}" values="0;1;0"/></circle>')
    def legend(s, items):
        y = s.h - 44
        s.top.append(f'<line x1="40" x2="{s.w-40}" y1="{y}" y2="{y}" stroke="{RULE}"/>')
        x = 40
        for kind, t in items:
            if kind == "arrow":
                s.top.append(f'<line x1="{x}" x2="{x+28}" y1="{y+22}" y2="{y+22}" stroke="{MUTED}" stroke-width="1.4" marker-end="url(#{s.slug}-a)"/>'); x += 36
            elif kind == "dash":
                s.top.append(f'<line x1="{x}" x2="{x+28}" y1="{y+22}" y2="{y+22}" stroke="{MUTED}" stroke-width="1.4" stroke-dasharray="5,4"/>'); x += 36
            elif kind == "dot":
                s.top.append(f'<circle cx="{x+6}" cy="{y+22}" r="4.5" fill="{ACC}"/>'); x += 20
            else:
                f, st = {"f": (ACCT, ACC), "n": ("#fff", INK), "x": (PAPER, SOFT)}[kind]
                s.top.append(f'<rect x="{x}" y="{y+15}" width="20" height="14" rx="3" fill="{f}" stroke="{st}"/>'); x += 28
            s.top.append(f'<text x="{x}" y="{y+26}" font-family="{MONO}" font-size="10" fill="{SOFT}">{esc(t)}</text>'); x += len(t)*6.2 + 28
    def save(s):
        open(OUT + s.slug + ".svg", "w").write(s.head + "\n".join(s.b) + "\n" + "\n".join(s.top) + "\n</svg>\n")

# 1 -- architecture
d = Svg("architecture", 960, 500, "System architecture", "One app, one shared database, works offline",
        "Three phone roles write through a local cache and queue to a shared Cloud Firestore project, guarded by security rules and Firebase Auth.")
ys = [172, 276, 380]
for y, n, sub in zip(ys, ("Admin phone", "Counter phone", "Scanner phone"), ("manage · approve · report", "scan · top-up · bill", "scan only")):
    d.arrow([(240, y), (340, y)])
    d.node(40, y-36, 200, 72, n, sub)
d.arrow([(540, 244), (640, 244)], accent=True); d.arrow([(640, 276), (540, 276)])
d.arrow([(780, 172), (780, 204)]); d.arrow([(780, 348), (780, 316)])
d.node(340, 124, 200, 272, "Local cache + queue", ("on every phone", "keeps scanning offline"), "s")
d.node(640, 204, 280, 112, "Cloud Firestore", ("canteens/{code}/…", "one shared project"), "f")
d.node(660, 116, 240, 56, "Security rules", "firestore.rules · per role")
d.node(660, 348, 240, 56, "Firebase Auth", "Google · Email · Anonymous")
d.label(590, 236, "WRITES"); d.label(590, 292, "SYNC")
d.label(822, 192, "ENFORCES", "start"); d.label(822, 336, "IDENTITY", "start")
d.note(340, 424, ["Works with no signal — syncs when it returns."])
for i, y in enumerate(ys):
    a = round(.02 + i*.05, 2); d.pulse([(240, y), (340, y)], a, a+.12, 8, INK)
d.pulse([(540, 244), (640, 244)], .30, .44, 8)
d.pulse([(640, 276), (540, 276)], .52, .66, 8, LINK)
for i, y in enumerate(ys):
    a = round(.70 + i*.04, 2); d.pulse([(340, y), (240, y)], a, a+.12, 8, LINK)
d.legend([("f", "Source of truth"), ("n", "Component"), ("arrow", "Data flow"), ("dot", "Live traffic")])
d.save()

# 2 -- scan flow
d = Svg("scan-flow", 1040, 500, "The scan, in one glance", "Five checks, one answer in a glance",
        "A scanned QR code passes five checks in order — known code, active member, meal time, first scan this meal, balance — then is accepted; any failure is rejected with a plain reason.")
xs = [16 + i*148 for i in range(7)]
spec = [("Scan QR", "camera", "n"), ("Known code?", "QR → member", "n"), ("Member active?", "not deactivated", "n"),
        ("In meal time?", "per Settings", "n"), ("Once per meal?", "one scan per day", "n"), ("Balance left?", "units + grace", "n"), ("Accept", "−1 unit · logged", "f")]
for i in range(6): d.arrow([(xs[i]+120, 172), (xs[i+1], 172)], accent=(i == 5))
for x in xs[1:6]: d.arrow([(x+60, 212), (x+60, 292)], dashed=True)
for x, (n, s_, k) in zip(xs, spec): d.node(x, 132, 120, 80, n, s_, k)
d.node(164, 292, 712, 64, "Reject — with a plain, specific reason", "shown in the operator's language · never a generic error", "s")
d.label(246, 258, "FAILS", "start")
d.note(16, 404, ["Offline? The same checks run on the phone's last-synced balance.",
                 "If two phones serve one meal, the server keeps the first and returns the unit."], 15)
d.pulse([(76, 172), (964, 172)], .02, .5, 8)
d.pulse([(76, 172), (520, 172), (520, 292)], .55, .95, 8, INK)
d.legend([("arrow", "Passes"), ("dash", "Fails"), ("dot", "Accepted scan"), ("f", "Outcome")])
d.save()

# 3 -- business loop
d = Svg("daily-loop", 960, 520, "How a canteen day works", "Prepaid units, served and restocked in a loop",
        "Members prepay units, units are spent at the counter, the menu plan sets headcount, headcount drives the shopping list, and costs are weighed against revenue.")
d.arrow([(320, 168), (640, 168)]); d.arrow([(760, 208), (760, 328)]); d.arrow([(640, 368), (320, 368)]); d.arrow([(200, 328), (200, 208)])
d.node(80, 128, 240, 80, "Top-up & bill", ("cash or UPI", "PDF bill"))
d.node(640, 128, 240, 80, "Scan at counter", ("−1 unit", "accept or reject"), "f")
d.node(640, 328, 240, 80, "Plan menu", ("per meal · per category", "planned headcount"))
d.node(80, 328, 240, 80, "Buy & stock", ("recipes → shopping list", "stock falls on each scan"))
d.label(480, 156, "UNITS"); d.label(838, 272, "HEADCOUNT", "start")
d.label(480, 396, "SHOPPING LIST"); d.label(212, 272, "MARGIN", "start")
d.note(480, 262, ["Every step writes to", "one shared ledger."], 20, "middle")
segs = [[(320, 168), (640, 168)], [(760, 208), (760, 328)], [(640, 368), (320, 368)], [(200, 328), (200, 208)]]
for i, p in enumerate(segs): d.pulse(p, round(i*.25+.02, 2), round(i*.25+.2, 2), 12)
d.legend([("f", "Most frequent moment"), ("n", "Step"), ("arrow", "Hand-off"), ("dot", "A day, repeating")])
d.save()

# 4 -- roles
d = Svg("roles", 960, 580, "Who can do what", "Three roles, one canteen",
        "A canteen has admin, counter and scanner roles with narrowing permissions; students and staff are scanned records, not logins.")
d.arrow([(420, 176), (420, 224), (172, 224), (172, 272)]); d.arrow([(480, 176), (480, 272)]); d.arrow([(540, 176), (540, 224), (788, 224), (788, 272)])
d.arrow([(480, 408), (480, 456)], dashed=True); d.arrow([(788, 408), (788, 456)], dashed=True)
d.node(360, 112, 240, 64, "A canteen", "canteens/{code}")
d.node(40, 272, 264, 136, "Admin", ("Everything", "members · menu · kitchen · refunds", "reports · users · phones"), "f")
d.node(348, 272, 264, 136, "Counter", ("Scan", "top-up & bill", "shared purchase schedule"))
d.node(656, 272, 264, 136, "Scanner", ("Scan only", "nothing else"))
d.node(348, 456, 572, 56, "Students & staff", "records, not logins · permanent QR · units per meal", "x")
d.label(496, 436, "SCAN", "start"); d.label(804, 436, "SCAN", "start")
d.note(40, 124, ["Each phone is approved with", "the narrowest role it needs;", "that role caps who can sign in on it."], 15)
for i, x in enumerate((420, 480, 540)):
    tgt = {420: [(420, 176), (420, 224), (172, 224), (172, 272)], 480: [(480, 176), (480, 272)], 540: [(540, 176), (540, 224), (788, 224), (788, 272)]}[x]
    d.pulse(tgt, round(.05+i*.12, 2), round(.25+i*.12, 2), 6)
d.legend([("f", "Full control"), ("n", "Limited role"), ("x", "Not a login"), ("dash", "Is scanned")])
d.save()

# 5 -- roadmap
d = Svg("roadmap", 960, 480, "Where the product stands", "Shipped, and what is planned next",
        "Four shipped milestones from LAN pilot to a shared offline-first Firebase platform, and four planned, uncommitted next steps.")
d.text(40, 124, "Shipped")
xs = [40, 264, 488, 712]
for i in range(3): d.arrow([(xs[i]+200, 176), (xs[i+1], 176)])
d.node(40, 136, 200, 80, "v1 · LAN pilot", ("browser + FastAPI", "MongoDB"))
d.node(264, 136, 200, 80, "v2 · Native app", ("one APK", "host phone on LAN"))
d.node(488, 136, 200, 80, "v3 · Offline-first", ("Firebase · 2026-10-17", "no host phone"))
d.node(712, 136, 200, 80, "Many canteens", ("one shared project", "2026-11-03"), "f")
d.text(40, 284, "Next · planned, not committed")
for x, n, a, b in zip(xs, ("Release hardening", "More sign-in", "Auto UPI confirm", "WhatsApp bills"),
                      ("App Check · create guard", "Apple · Microsoft · phone", "gateway webhook", "bill delivery"),
                      ("needed before public release", "need external setup", "manual today", "deferred")):
    d.node(x, 304, 200, 88, n, (a, b), "x")
d.top.append(f'<rect x="708" y="132" width="208" height="88" rx="9" fill="none" stroke="{ACC}" stroke-width="1.4" opacity="0"><animate attributeName="opacity" values="0;.9;0" dur="2.4s" repeatCount="indefinite"/></rect>')
d.label(812, 240, "YOU ARE HERE")
d.pulse([(240, 176), (264, 176)], .0, .0, 1) if False else None
d.pulse([(140, 176), (264, 176), (464, 176), (488, 176), (688, 176), (712, 176)], .05, .6, 8)
d.legend([("f", "Latest milestone"), ("n", "Shipped"), ("x", "Planned"), ("dot", "Progress")])
d.save()
print("ok")
