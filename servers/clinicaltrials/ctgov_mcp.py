"""ClinicalTrials.gov MCP server (read-only) over the public API v2.

No credentials required. Tools are intentionally narrow and return compact JSON
so they are cheap for Gemini Enterprise to consume.
API reference: https://clinicaltrials.gov/data-api/api
"""

from __future__ import annotations

import os
from typing import Any

import httpx
from fastmcp import FastMCP
from mcp.types import ToolAnnotations

BASE = "https://clinicaltrials.gov/api/v2"
UA = os.environ.get("CTGOV_USER_AGENT", "telix-connectors/0.1 (contact: it@telixpharma.com)")
RO = ToolAnnotations(readOnlyHint=True, openWorldHint=True)

mcp = FastMCP("clinicaltrials")

_FIELDS = ",".join(
    [
        "NCTId", "BriefTitle", "OverallStatus", "Phase", "StudyType", "Condition",
        "InterventionName", "LeadSponsorName", "EnrollmentCount", "StartDate",
        "PrimaryCompletionDate", "LocationCountry",
    ]
)


async def _get(path: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
    async with httpx.AsyncClient(timeout=30, headers={"User-Agent": UA}) as c:
        r = await c.get(f"{BASE}{path}", params=params)
        r.raise_for_status()
        return r.json()


def _m(study: dict) -> dict:
    """Flatten a v2 study record to the handful of fields researchers ask for."""
    p = study.get("protocolSection", {})
    idm, st, des, cond, arms, spons, loc = (
        p.get("identificationModule", {}), p.get("statusModule", {}), p.get("designModule", {}),
        p.get("conditionsModule", {}), p.get("armsInterventionsModule", {}),
        p.get("sponsorCollaboratorsModule", {}), p.get("contactsLocationsModule", {}),
    )
    return {
        "nct_id": idm.get("nctId"),
        "title": idm.get("briefTitle"),
        "status": st.get("overallStatus"),
        "phases": des.get("phases"),
        "study_type": des.get("studyType"),
        "conditions": cond.get("conditions"),
        "interventions": [i.get("name") for i in arms.get("interventions", [])],
        "sponsor": spons.get("leadSponsor", {}).get("name"),
        "enrollment": des.get("enrollmentInfo", {}).get("count"),
        "start_date": st.get("startDateStruct", {}).get("date"),
        "primary_completion": st.get("primaryCompletionDateStruct", {}).get("date"),
        "countries": sorted({l.get("country") for l in loc.get("locations", []) if l.get("country")}),
        "url": f"https://clinicaltrials.gov/study/{idm.get('nctId')}",
    }


@mcp.tool(annotations=RO)
async def search_trials(
    query: str,
    condition: str | None = None,
    intervention: str | None = None,
    status: str | None = None,
    phase: str | None = None,
    country: str | None = None,
    page_size: int = 10,
) -> dict:
    """Search ClinicalTrials.gov studies.

    Args:
      query: free-text terms (e.g. "177Lu PSMA", "CAIX girentuximab").
      condition: condition filter (e.g. "prostate cancer").
      intervention: intervention/drug filter (e.g. "Illuccix").
      status: comma list of RECRUITING, ACTIVE_NOT_RECRUITING, COMPLETED, NOT_YET_RECRUITING, TERMINATED...
      phase: PHASE1 | PHASE2 | PHASE3 | PHASE4 | EARLY_PHASE1.
      country: e.g. "Australia".
      page_size: 1-50.
    """
    params: dict[str, Any] = {"query.term": query, "pageSize": max(1, min(page_size, 50)), "fields": _FIELDS, "countTotal": "true"}
    if condition:
        params["query.cond"] = condition
    if intervention:
        params["query.intr"] = intervention
    if status:
        params["filter.overallStatus"] = status
    if country:
        params["query.locn"] = country
    if phase:
        params["filter.advanced"] = f"AREA[Phase]{phase}"
    data = await _get("/studies", params)
    return {"total": data.get("totalCount"), "studies": [_m(s) for s in data.get("studies", [])]}


@mcp.tool(annotations=RO)
async def get_trial(nct_id: str) -> dict:
    """Get a single study by NCT id (e.g. NCT04689828). Returns summary + eligibility + outcomes."""
    s = await _get(f"/studies/{nct_id.strip().upper()}")
    p = s.get("protocolSection", {})
    out = _m(s)
    out["brief_summary"] = p.get("descriptionModule", {}).get("briefSummary")
    out["eligibility"] = p.get("eligibilityModule", {}).get("eligibilityCriteria")
    out["primary_outcomes"] = p.get("outcomesModule", {}).get("primaryOutcomes")
    out["has_results"] = s.get("hasResults")
    return out


@mcp.tool(annotations=RO)
async def trial_locations(nct_id: str) -> dict:
    """List sites (facility, city, country, status) for a study."""
    s = await _get(f"/studies/{nct_id.strip().upper()}", {"fields": "NCTId,LocationFacility,LocationCity,LocationCountry,LocationStatus"})
    locs = s.get("protocolSection", {}).get("contactsLocationsModule", {}).get("locations", [])
    return {"nct_id": nct_id.upper(), "count": len(locs), "locations": [
        {"facility": l.get("facility"), "city": l.get("city"), "country": l.get("country"), "status": l.get("status")} for l in locs
    ]}


@mcp.tool(annotations=RO)
async def trials_by_sponsor(sponsor: str, status: str | None = None, page_size: int = 20) -> dict:
    """List studies for a lead sponsor (e.g. "Telix", "Novartis") for competitive landscape."""
    params: dict[str, Any] = {"query.spons": sponsor, "pageSize": max(1, min(page_size, 50)), "fields": _FIELDS, "countTotal": "true"}
    if status:
        params["filter.overallStatus"] = status
    data = await _get("/studies", params)
    return {"total": data.get("totalCount"), "studies": [_m(s) for s in data.get("studies", [])]}


if __name__ == "__main__":
    mcp.run()  # stdio; the template proxy wraps this for HTTP
