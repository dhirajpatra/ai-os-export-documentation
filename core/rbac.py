"""
TradeOS — RBAC + Organization Layer
======================================
Exporter orgs · Departments · Roles · Permissions · Approval chains
Row-level security enforced at DB layer.
JWT-based auth with org_id embedded.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from enum import Enum
from typing import Any


# ─────────────────────────────────────────────
# ROLES & PERMISSIONS
# ─────────────────────────────────────────────

class Role(str, Enum):
    OWNER    = "owner"      # Full access, billing, org settings
    ADMIN    = "admin"      # Full access except billing
    MANAGER  = "manager"    # Approve docs, manage team, no settings
    OPERATOR = "operator"   # Create/edit orders & docs, no approvals
    VIEWER   = "viewer"     # Read-only across all modules
    CUSTOMS  = "customs"    # Compliance module only
    FINANCE  = "finance"    # Finance module only
    LOGISTICS= "logistics"  # Logistics/tracking only


# Permission → set of roles that can perform it
PERMISSIONS: dict[str, set[Role]] = {
    # Org management
    "org:manage":           {Role.OWNER},
    "org:billing":          {Role.OWNER},
    "users:invite":         {Role.OWNER, Role.ADMIN},
    "users:manage":         {Role.OWNER, Role.ADMIN},

    # Orders
    "orders:create":        {Role.OWNER, Role.ADMIN, Role.MANAGER, Role.OPERATOR},
    "orders:edit":          {Role.OWNER, Role.ADMIN, Role.MANAGER, Role.OPERATOR},
    "orders:delete":        {Role.OWNER, Role.ADMIN},
    "orders:view":          {Role.OWNER, Role.ADMIN, Role.MANAGER, Role.OPERATOR, Role.VIEWER},

    # Documents
    "documents:generate":   {Role.OWNER, Role.ADMIN, Role.MANAGER, Role.OPERATOR},
    "documents:approve":    {Role.OWNER, Role.ADMIN, Role.MANAGER},
    "documents:reject":     {Role.OWNER, Role.ADMIN, Role.MANAGER},
    "documents:send":       {Role.OWNER, Role.ADMIN, Role.MANAGER, Role.OPERATOR},
    "documents:view":       {Role.OWNER, Role.ADMIN, Role.MANAGER, Role.OPERATOR, Role.VIEWER,
                             Role.CUSTOMS, Role.FINANCE, Role.LOGISTICS},

    # Compliance
    "compliance:view":      {Role.OWNER, Role.ADMIN, Role.MANAGER, Role.OPERATOR,
                             Role.VIEWER, Role.CUSTOMS},
    "compliance:override":  {Role.OWNER, Role.ADMIN, Role.CUSTOMS},

    # Finance
    "finance:view":         {Role.OWNER, Role.ADMIN, Role.MANAGER, Role.FINANCE, Role.VIEWER},
    "finance:approve":      {Role.OWNER, Role.ADMIN, Role.FINANCE},
    "finance:export":       {Role.OWNER, Role.ADMIN, Role.FINANCE},

    # Logistics
    "logistics:view":       {Role.OWNER, Role.ADMIN, Role.MANAGER, Role.OPERATOR,
                             Role.LOGISTICS, Role.VIEWER},
    "logistics:update":     {Role.OWNER, Role.ADMIN, Role.MANAGER, Role.LOGISTICS},

    # Approvals
    "approvals:view_own":   {Role.OWNER, Role.ADMIN, Role.MANAGER},
    "approvals:view_all":   {Role.OWNER, Role.ADMIN},

    # Settings
    "settings:agents":      {Role.OWNER, Role.ADMIN},
    "settings:integrations":{Role.OWNER, Role.ADMIN},
    "settings:prompts":     {Role.OWNER, Role.ADMIN},
    "settings:webhooks":    {Role.OWNER, Role.ADMIN},

    # AI / Memory
    "memory:view":          {Role.OWNER, Role.ADMIN},
    "memory:delete":        {Role.OWNER},
    "audit:view":           {Role.OWNER, Role.ADMIN},
}


def check_permission(role: str, permission: str) -> bool:
    allowed = PERMISSIONS.get(permission, set())
    return Role(role) in allowed


def require_permission(role: str, permission: str):
    if not check_permission(role, permission):
        raise PermissionError(f"Role '{role}' cannot perform '{permission}'")


# ─────────────────────────────────────────────
# APPROVAL CHAIN CONFIG
# ─────────────────────────────────────────────

@dataclass
class ApprovalRule:
    """
    When does a document/action require approval?
    Rules are evaluated in priority order; first match wins.
    """
    name:         str
    priority:     int
    condition:    str                   # "confidence < 80", "amount > 50000", etc.
    required_role: Role = Role.MANAGER
    escalate_to:  Role | None = None   # if primary approver doesn't act in SLA
    sla_hours:    int = 4
    notify_channels: list[str] = field(default_factory=lambda: ["email", "whatsapp"])


DEFAULT_APPROVAL_RULES: list[ApprovalRule] = [
    ApprovalRule(
        name         = "Low AI Confidence",
        priority     = 10,
        condition    = "confidence < 70",
        required_role= Role.MANAGER,
        escalate_to  = Role.ADMIN,
        sla_hours    = 2,
    ),
    ApprovalRule(
        name         = "High Value Order",
        priority     = 20,
        condition    = "order_amount > 100000",
        required_role= Role.MANAGER,
        escalate_to  = Role.OWNER,
        sla_hours    = 4,
    ),
    ApprovalRule(
        name         = "New Buyer First Order",
        priority     = 30,
        condition    = "buyer_order_count == 1",
        required_role= Role.OPERATOR,
        sla_hours    = 8,
    ),
    ApprovalRule(
        name         = "Compliance Flag",
        priority     = 5,
        condition    = "has_critical_compliance_flag",
        required_role= Role.ADMIN,
        escalate_to  = Role.OWNER,
        sla_hours    = 1,
    ),
    ApprovalRule(
        name         = "LC Document",
        priority     = 25,
        condition    = "payment_terms == 'LC'",
        required_role= Role.FINANCE,
        sla_hours    = 4,
    ),
]


def evaluate_approval_rules(context: dict, rules: list[ApprovalRule]) -> ApprovalRule | None:
    """Return the first matching rule, or None if no approval needed."""
    for rule in sorted(rules, key=lambda r: r.priority):
        if _eval_condition(rule.condition, context):
            return rule
    return None


def _eval_condition(condition: str, ctx: dict) -> bool:
    """Safe condition evaluator — no eval()."""
    c = condition.strip()
    if "confidence <" in c:
        threshold = float(c.split("<")[1].strip())
        return float(ctx.get("confidence", 100)) < threshold
    if "confidence >" in c:
        threshold = float(c.split(">")[1].strip())
        return float(ctx.get("confidence", 0)) > threshold
    if "order_amount >" in c:
        threshold = float(c.split(">")[1].strip())
        return float(ctx.get("order_amount", 0)) > threshold
    if "buyer_order_count ==" in c:
        count = int(c.split("==")[1].strip())
        return int(ctx.get("buyer_order_count", 0)) == count
    if "has_critical_compliance_flag" in c:
        return bool(ctx.get("has_critical_compliance_flag", False))
    if "payment_terms ==" in c:
        term = c.split("==")[1].strip().strip("'\"")
        return str(ctx.get("payment_terms", "")) == term
    return False


# ─────────────────────────────────────────────
# AUTH TOKENS
# ─────────────────────────────────────────────

@dataclass
class TokenPayload:
    sub:         str           # user_id
    org_id:      str
    role:        str
    email:       str
    exp:         int           # unix timestamp
    permissions: list[str] = field(default_factory=list)


def create_access_token(payload: TokenPayload, secret: str, algo: str = "HS256") -> str:
    import time, base64, hmac, hashlib, json
    header  = base64.urlsafe_b64encode(json.dumps({"alg": algo, "typ": "JWT"}).encode()).rstrip(b"=")
    body    = base64.urlsafe_b64encode(json.dumps({
        "sub":    payload.sub,
        "org_id": payload.org_id,
        "role":   payload.role,
        "email":  payload.email,
        "exp":    payload.exp,
    }).encode()).rstrip(b"=")
    sig_input = header + b"." + body
    sig       = base64.urlsafe_b64encode(
        hmac.new(secret.encode(), sig_input, hashlib.sha256).digest()
    ).rstrip(b"=")
    return (sig_input + b"." + sig).decode()


def decode_access_token(token: str, secret: str) -> TokenPayload:
    import base64, hmac, hashlib, json, time
    parts = token.split(".")
    if len(parts) != 3:
        raise ValueError("Invalid token format")
    header, body, sig = parts
    sig_input  = f"{header}.{body}".encode()
    expected   = base64.urlsafe_b64encode(
        hmac.new(secret.encode(), sig_input, hashlib.sha256).digest()
    ).rstrip(b"=").decode()
    if expected != sig:
        raise ValueError("Token signature invalid")
    padding = 4 - len(body) % 4
    payload = json.loads(base64.urlsafe_b64decode(body + "=" * padding))
    if payload["exp"] < int(time.time()):
        raise ValueError("Token expired")
    return TokenPayload(**{k: v for k, v in payload.items() if k in TokenPayload.__dataclass_fields__})


# ─────────────────────────────────────────────
# TENANT RESOLVER
# Maps WhatsApp phone numbers → org_id
# ─────────────────────────────────────────────

class TenantResolver:
    """
    Resolve which org a WhatsApp message or API key belongs to.
    In production: backed by Redis cache + DB lookup.
    """

    _phone_to_org:  dict[str, str] = {}
    _apikey_to_org: dict[str, str] = {}

    @classmethod
    def register_phone(cls, phone: str, org_id: str):
        cls._phone_to_org[phone] = org_id

    @classmethod
    def register_apikey(cls, api_key_hash: str, org_id: str):
        cls._apikey_to_org[api_key_hash] = org_id

    @classmethod
    def resolve_phone(cls, phone: str) -> str | None:
        return cls._phone_to_org.get(phone)

    @classmethod
    def resolve_apikey(cls, api_key: str) -> str | None:
        import hashlib
        key_hash = hashlib.sha256(api_key.encode()).hexdigest()
        return cls._apikey_to_org.get(key_hash)
