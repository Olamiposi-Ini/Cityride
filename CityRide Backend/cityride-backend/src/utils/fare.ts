import { distanceKm } from "./geo";

const BASE_FARE_NAIRA = 500;
const PER_KM_NAIRA = 250;
const MINIMUM_FARE_NAIRA = 700;

type Coordinates = {
  lat: number;
  lng: number;
};

export function estimateFare(pickup: Coordinates, destination: Coordinates) {
  const tripDistanceKm = distanceKm(pickup, destination);
  const fare = Math.max(
    MINIMUM_FARE_NAIRA,
    Math.round(BASE_FARE_NAIRA + tripDistanceKm * PER_KM_NAIRA)
  );

  return {
    distanceKm: Number(tripDistanceKm.toFixed(2)),
    fareEstimate: fare
  };
}
