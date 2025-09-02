# 🛡️ DFIR Hive Toolkit (Safe Forensic Training)

A portable toolkit for **offline collection and analysis of Windows registry hives**.  
Designed for **DFIR labs**, **training environments**, and **forensic simulations** — not live exploitation.

This project demonstrates **evidence handling, offline decoding, and hash cracking workflows** commonly used in real digital forensics investigations.

---

## 🎯 Scope
- Collects **Windows SAM / SYSTEM / SECURITY hives** in a safe, offline manner (WinRE, Admin CMD, or Linux live).  
- Decodes with [Impacket](https://github.com/fortra/impacket) `secretsdump.py` into structured logs.  
- Automates optional **password hash cracking with Hashcat** for training purposes.  
- Supports **multi-target labeling** to keep evidence organized.  
- Runs fully from USB, leaving no traces on host systems.

> ⚠️ For **educational and authorized use only**. This toolkit is intentionally limited to safe lab use.

---


