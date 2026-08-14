#include "sx/joints.hpp"

#include <algorithm>
#include <cmath>

#include <gp_Dir.hxx>
#include <stdexcept>

#include <gp_Ax1.hxx>
#include <gp_Quaternion.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include "sx/document.hpp"
#include "sx/instances.hpp"

namespace sx {

const char* to_string(JointType t) {
    switch (t) {
        case JointType::Revolute: return "revolute";
        case JointType::Slider: return "slider";
        case JointType::Cylindrical: return "cylindrical";
        case JointType::Planar: return "planar";
        case JointType::Ball: return "ball";
        case JointType::PinSlot: return "pin_slot";
    }
    return "unknown";
}

JointType joint_type_from_string(const std::string& s) {
    if (s == "revolute") return JointType::Revolute;
    if (s == "slider") return JointType::Slider;
    if (s == "cylindrical") return JointType::Cylindrical;
    if (s == "planar") return JointType::Planar;
    if (s == "ball") return JointType::Ball;
    if (s == "pin_slot") return JointType::PinSlot;
    throw std::invalid_argument("unknown joint type: " + s);
}

void to_json(nlohmann::json& j, const Joint& jnt) {
    j = nlohmann::json{
        {"uuid", jnt.id.str()},
        {"type", to_string(jnt.type)},
        {"a", jnt.a},
        {"b", jnt.b},
        {"limit_min", jnt.limit_min},
        {"limit_max", jnt.limit_max},
        {"has_limits", jnt.has_limits},
        {"name", jnt.name},
    };
}

void from_json(const nlohmann::json& j, Joint& jnt) {
    if (j.contains("uuid")) jnt.id = EntityId::from_string(j["uuid"].get<std::string>());
    jnt.type = joint_type_from_string(j.at("type").get<std::string>());
    if (j.contains("a")) jnt.a = j["a"].get<MateConnector>();
    if (j.contains("b")) jnt.b = j["b"].get<MateConnector>();
    jnt.limit_min = j.value("limit_min", 0.0);
    jnt.limit_max = j.value("limit_max", 0.0);
    jnt.has_limits = j.value("has_limits", false);
    jnt.name = j.value("name", "");
}

namespace {

bool move_instance(Document& doc, const EntityId& instance_id, const gp_Trsf& correction) {
    const Instance* inst = doc.instance(instance_id);
    if (!inst) return false;
    gp_Trsf t = correction * transform_of(*inst);
    gp_Quaternion q = t.GetRotation();
    gp_XYZ tr = t.TranslationPart();
    return doc.set_instance_transform(instance_id, {tr.X(), tr.Y(), tr.Z()},
                                      {q.X(), q.Y(), q.Z(), q.W()});
}

gp_Trsf rotation_about(const gp_Pnt& about, const gp_Dir& from, const gp_Dir& to) {
    gp_Trsf out;
    gp_Quaternion q{gp_Vec(from), gp_Vec(to)};
    gp_Trsf rot;
    rot.SetRotation(q);
    gp_Trsf to_origin, back;
    to_origin.SetTranslation(gp_Vec(about.XYZ().Reversed()));
    back.SetTranslation(gp_Vec(about.XYZ()));
    return back * rot * to_origin;
}

}  // namespace

bool apply_joint(Document& doc, const Joint& jnt, double s) {
    if (jnt.b.instance.is_null() || !doc.instance(jnt.b.instance)) return false;
    gp_Pnt oa(jnt.a.origin[0], jnt.a.origin[1], jnt.a.origin[2]);
    gp_Pnt ob(jnt.b.origin[0], jnt.b.origin[1], jnt.b.origin[2]);
    gp_Dir za(jnt.a.z_dir[0], jnt.a.z_dir[1], jnt.a.z_dir[2]);
    gp_Dir zb(jnt.b.z_dir[0], jnt.b.z_dir[1], jnt.b.z_dir[2]);
    double param = s;
    if (jnt.has_limits) param = std::clamp(s, jnt.limit_min, jnt.limit_max);

    switch (jnt.type) {
        case JointType::Ball: {
            gp_Trsf shift;
            shift.SetTranslation(gp_Vec(ob, oa));
            return move_instance(doc, jnt.b.instance, shift);
        }
        case JointType::Slider: {
            gp_Trsf corr = rotation_about(ob, zb, za);
            gp_Pnt dest = oa.Translated(gp_Vec(za) * param);
            gp_Trsf shift;
            shift.SetTranslation(gp_Vec(ob, dest));
            return move_instance(doc, jnt.b.instance, shift * corr);
        }
        case JointType::Revolute:
        case JointType::Cylindrical: {
            gp_Trsf corr = rotation_about(ob, zb, za);
            gp_Trsf spin;
            spin.SetRotation(gp_Ax1(ob, za), param);
            gp_Pnt dest = (jnt.type == JointType::Cylindrical)
                              ? oa.Translated(gp_Vec(za) * 0.0)
                              : oa;
            gp_Trsf shift;
            shift.SetTranslation(gp_Vec(ob, dest));
            return move_instance(doc, jnt.b.instance, shift * spin * corr);
        }
        case JointType::Planar:
        case JointType::PinSlot: {
            gp_Trsf corr = rotation_about(ob, zb, za);
            gp_Vec v(ob, oa);
            gp_Vec axial = gp_Vec(za) * v.Dot(gp_Vec(za));
            gp_Trsf shift;
            if (jnt.type == JointType::PinSlot)
                shift.SetTranslation(v - axial);  // kill radial, keep slide
            else
                shift.SetTranslation(gp_Vec(za) * (v.Dot(gp_Vec(za))));  // close normal
            return move_instance(doc, jnt.b.instance, shift * corr);
        }
    }
    return false;
}

double crank_slider_x(double crank, double rod, double theta) {
    // x = a cos θ + sqrt(b² − a² sin² θ)
    const double s = std::sin(theta);
    const double inner = rod * rod - crank * crank * s * s;
    if (inner < 0.0) return crank * std::cos(theta);
    return crank * std::cos(theta) + std::sqrt(inner);
}

}  // namespace sx
