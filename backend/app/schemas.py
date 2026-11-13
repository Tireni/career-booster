from pydantic import BaseModel, Field


class AnalysisResult(BaseModel):
    match_score: int = Field(ge=0, le=100)
    summary: str = Field(min_length=1, max_length=3000)
    matched_keywords: list[str] = Field(max_length=30)
    missing_keywords: list[str] = Field(max_length=30)
    tailored_bullets: list[str] = Field(max_length=12)
    cover_letter: str = Field(min_length=1, max_length=10000)
    cautions: list[str] = Field(default_factory=list, max_length=12)
