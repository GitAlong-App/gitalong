from app.services import collab
from tests.conftest import make_user


def test_symmetric_and_complementary_intents():
    assert collab.intent_compatibility(["cofounder"], ["cofounder"]) == 1.0
    assert collab.intent_compatibility(["mentee"], ["mentor"]) == 1.0
    assert collab.intent_compatibility(["mentor"], ["mentor"]) == 0.0  # two mentors isn't a match
    assert collab.intent_compatibility(["cofounder"], ["hackathon"]) == 0.0


def test_unknown_intent_is_neutral():
    assert collab.intent_compatibility([], ["cofounder"]) == 0.5
    assert collab.intent_compatibility(["not-an-intent"], ["cofounder"]) == 0.5


def test_skill_complement_is_bidirectional_and_case_insensitive():
    viewer = make_user("v", languages=["Rust"], seeking_skills=["typescript"])
    cand = make_user("c", languages=["TypeScript", "Go"], seeking_skills=["Rust", "Swift"])
    # viewer gets 1/1 of what they seek, candidate gets 1/2
    assert collab.skill_complement(viewer, cand) == 0.75
    assert collab.skill_complement(make_user("a"), make_user("b")) == 0.0


def test_match_reasons_are_human_and_ordered():
    viewer = make_user(
        "v", languages=["Rust", "Go"], interests=["AI / ML"], looking_for=["cofounder"],
        seeking_skills=["TypeScript"], location="Berlin, Germany",
    )
    cand = make_user(
        "c", languages=["TypeScript", "Rust"], interests=["ai / ml"], looking_for=["cofounder"],
        location="Berlin", total_stars=1234,
    )
    reasons = collab.match_reasons(viewer, cand, limit=10)
    assert reasons[0] == "You're both looking for a co-founder"
    assert "Knows TypeScript — a skill you want" in reasons
    assert "You both write Rust" in reasons
    assert "Both into AI / ML" in reasons
    assert "Also in Berlin" in reasons
    assert "1.2k stars earned on GitHub" in reasons
    assert collab.match_reasons(viewer, cand) == reasons[:3]


def test_mentor_reasons_read_from_viewer_perspective():
    mentee = make_user("m", looking_for=["mentee"])
    mentor = make_user("t", looking_for=["mentor"])
    assert collab.match_reasons(mentee, mentor)[0] == "Mentors developers — you're looking for a mentor"
    assert collab.match_reasons(mentor, mentee)[0] == "Looking for a mentor — you mentor"


def test_human_join():
    assert collab.human_join(["a"]) == "a"
    assert collab.human_join(["a", "b", "c"]) == "a, b and c"
