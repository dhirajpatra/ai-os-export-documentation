from typing import Dict, Any, List
import json
import logging

logger = logging.getLogger(__name__)

class FreightIntelligence:
    """
    Freight Intelligence Module.
    Responsible for estimating logistics costs and handling rate cards for various vendors.
    """
    
    def __init__(self):
        # We could initialize DB connection or load configuration here
        pass
        
    def estimate_logistics_cost(self, volume_cbm: float, weight_ton: float, rate_card: Dict[str, Any], is_hazardous: bool = False) -> Dict[str, Any]:
        """
        Estimates the logistics cost based on volume/weight and a vendor's rate card.
        
        Args:
            volume_cbm: The volume of the shipment in CBM
            weight_ton: The weight of the shipment in tons
            rate_card: A dictionary representing the vendor's rate card, like:
                {
                  "vendor": "JN Freight",
                  "service_type": "LCL Import Consolidation",
                  "charges": {
                    "CHC": { "cbm_rate": 1350, "ton_rate": 1700, "minimum": 1700 },
                    "hazardous": { "cbm_rate": 1350, "minimum_cbm": 4 },
                    "do_fee": 4500,
                    "service_fee": 7500
                  },
                  "gst_applicable": true
                }
            is_hazardous: Whether the shipment is hazardous
            
        Returns:
            A dictionary with estimated cost breakdown and total.
        """
        try:
            charges = rate_card.get("charges", {})
            breakdown = {}
            total_cost = 0.0
            
            # 1. Calculate CHC (Container Handling Charges)
            chc_rates = charges.get("CHC", {})
            chc_by_volume = volume_cbm * chc_rates.get("cbm_rate", 0)
            chc_by_weight = weight_ton * chc_rates.get("ton_rate", 0)
            # Usually takes the higher of the two, or based on minimum
            calculated_chc = max(chc_by_volume, chc_by_weight)
            calculated_chc = max(calculated_chc, chc_rates.get("minimum", 0))
            
            if calculated_chc > 0:
                breakdown["CHC"] = calculated_chc
                total_cost += calculated_chc
            
            # 2. Hazardous Surcharge
            if is_hazardous:
                haz_rates = charges.get("hazardous", {})
                haz_cbm = max(volume_cbm, haz_rates.get("minimum_cbm", 0))
                calculated_haz = haz_cbm * haz_rates.get("cbm_rate", 0)
                if calculated_haz > 0:
                    breakdown["Hazardous Surcharge"] = calculated_haz
                    total_cost += calculated_haz
            
            # 3. DO Fee (Delivery Order)
            do_fee = charges.get("do_fee", 0)
            if do_fee > 0:
                breakdown["DO Fee"] = do_fee
                total_cost += do_fee
                
            # 4. Service Fee (Freight/Service)
            service_fee = charges.get("service_fee", 0)
            if service_fee > 0:
                breakdown["Service Fee"] = service_fee
                total_cost += service_fee
                
            # 5. GST
            if rate_card.get("gst_applicable", False):
                # Assuming 18% standard GST rate in India for such logistics services
                gst_amount = total_cost * 0.18
                breakdown["GST (18%)"] = gst_amount
                total_cost += gst_amount
                
            # AI formatting simulation as requested:
            # "Estimated logistics cost: ₹24,300"
            # "Breakdown: CHC, DO Fee, Freight, Customs, GST"
            
            ai_summary = (
                f"Estimated logistics cost: \n"
                f"₹{int(total_cost):,}\n\n"
                f"Breakdown:\n"
            )
            for item, amount in breakdown.items():
                ai_summary += f"• {item}: ₹{int(amount):,}\n"
                
            return {
                "success": True,
                "total_estimated_cost": total_cost,
                "currency": "INR",
                "breakdown": breakdown,
                "vendor_info": {
                    "vendor": rate_card.get("vendor", "Unknown"),
                    "service_type": rate_card.get("service_type", "Unknown")
                },
                "ai_summary": ai_summary
            }
            
        except Exception as e:
            logger.error(f"Error estimating logistics cost: {str(e)}")
            return {
                "success": False,
                "error": str(e)
            }
